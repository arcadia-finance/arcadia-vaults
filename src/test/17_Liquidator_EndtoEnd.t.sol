/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import {LendingPool, DebtToken, ERC20, DataTypes} from "../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../lib/arcadia-lending/src/Tranche.sol";

contract LiquidatorEndToEnd is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    LendingPool public pool;
    Tranche public SrTranche;
    Tranche public JrTranche;

    address[] public oracleSafemoonToUsdArr = new address[](1);
    uint256 rateSafemoonToUsd = 5 * 10 ** Constants.oracleSafemoonToUsdDecimals;
    ArcadiaOracle public oracleSafemoonToUsd;

    // address public creatorAddress = address(1);
    // address public tokenCreatorAddress = address(2);
    // address public oracleOwner = address(3);
    // address public unprivilegedAddress = address(4);
    // address public vaultOwner = address(6);
    // address public liquidityProvider = address(7);
    address public treasuryAddress = address(8);

    address public liqProviderSr1 = address(9);
    address public liqProviderSr2 = address(10);
    address public liqProviderJr1 = address(11);
    address public liqProviderJr2 = address(12);

    address public vaultOwner1 = address(13);
    address public vaultOwner2 = address(14);

    Vault public proxy1;
    Vault public proxy2;

    address public liquidationInitiator = address(15);
    address public auctionBuyer = address(16);

    uint256 public priceOfVault;

    constructor() DeployArcadiaVaults() {
        vm.startPrank(liquidityProvider);
        dai.transfer(liqProviderSr1, 1_000_000 * 10 ** Constants.daiDecimals);
        dai.transfer(liqProviderSr2, 1_000_000 * 10 ** Constants.daiDecimals);
        dai.transfer(liqProviderJr1, 1_000_000 * 10 ** Constants.daiDecimals);
        dai.transfer(liqProviderJr2, 1_000_000 * 10 ** Constants.daiDecimals);
        dai.transfer(auctionBuyer, 1_000_000 * 10 ** Constants.daiDecimals);
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        link.mint(vaultOwner1, 1_000_000 * 10 ** Constants.linkDecimals);
        link.mint(vaultOwner2, 1_000_000 * 10 ** Constants.linkDecimals);
        eth.mint(vaultOwner1, 100_000 * 10 ** Constants.ethDecimals);
        eth.mint(vaultOwner2, 100_00 * 10 ** Constants.ethDecimals);
        safemoon.mint(vaultOwner1, 100_000 * 10 ** Constants.safemoonDecimals);
        vm.stopPrank();

        oracleSafemoonToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleSafemoonToUsdDecimals), "SAFE / USD");
        vm.startPrank(oracleOwner);
        oracleSafemoonToUsd.transmit(int256(rateSafemoonToUsd));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        oracleSafemoonToUsdArr[0] = address(oracleSafemoonToUsd);

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSafemoonToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "SAFE",
                baseAsset: "USD",
                oracle: address(oracleSafemoonToUsd),
                quoteAssetAddress: address(safemoon),
                baseAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );
        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );
        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );

        PricingModule.RiskVarInput[] memory riskVars_ = riskVars;

        standardERC20PricingModule.addAsset(address(safemoon), oracleSafemoonToUsdArr, riskVars_, type(uint128).max);

        liquidator = new Liquidator(address(factory));

        pool = new LendingPool(ERC20(address(dai)), treasuryAddress, address(factory));
        pool.setLiquidator(address(liquidator));
        pool.setVaultVersion(1, true);
        DataTypes.InterestRateConfiguration memory config = DataTypes.InterestRateConfiguration({
            baseRatePerYear: Constants.interestRate,
            highSlopePerYear: Constants.interestRate,
            lowSlopePerYear: Constants.interestRate,
            utilisationThreshold: Constants.utilisationThreshold
        });
        pool.setInterestConfig(config);

        SrTranche = new Tranche(address(pool), "Senior", "SR");
        JrTranche = new Tranche(address(pool), "Junior", "JR");
        pool.addTranche(address(SrTranche), 50, 0);
        pool.addTranche(address(JrTranche), 40, 20);
        pool.setTreasuryInterestWeight(10);
        pool.setTreasuryLiquidationWeight(80);
        pool.setOriginationFee(10);
        vm.stopPrank();

        vm.startPrank(liqProviderSr1);
        dai.approve(address(pool), type(uint256).max);
        SrTranche.deposit(1_000_000 * 10 ** Constants.daiDecimals, liqProviderSr1);
        vm.stopPrank();

        vm.startPrank(liqProviderSr2);
        dai.approve(address(pool), type(uint256).max);
        SrTranche.deposit(100_000 * 10 ** Constants.daiDecimals, liqProviderSr2);
        vm.stopPrank();

        vm.startPrank(liqProviderJr1);
        dai.approve(address(pool), type(uint256).max);
        JrTranche.deposit(1_000_000 * 10 ** Constants.daiDecimals, liqProviderJr1);
        vm.stopPrank();

        vm.startPrank(liqProviderJr2);
        dai.approve(address(pool), type(uint256).max);
        JrTranche.deposit(100_000 * 10 ** Constants.daiDecimals, liqProviderJr2);
        vm.stopPrank();

        vm.prank(auctionBuyer);
        dai.approve(address(liquidator), type(uint256).max);
    }

    //this is a before each
    function setUp() public virtual {
        address[] memory tokens1 = new address[](3);
        tokens1[0] = address(link);
        tokens1[1] = address(eth);
        tokens1[2] = address(safemoon);

        uint256[] memory ids1 = new uint256[](3);
        ids1[0] = 0;
        ids1[1] = 0;
        ids1[2] = 0;

        uint256[] memory amounts1 = new uint256[](3); // total value = 100_000 + 300_000 + 500_000, coll value = 450_000, liq value = 500_000
        amounts1[0] = 5_000 * 10 ** Constants.linkDecimals;
        amounts1[1] = 100 * 10 ** Constants.ethDecimals;
        amounts1[2] = 100_000 * 10 ** Constants.safemoonDecimals;

        uint256[] memory types1 = new uint256[](3);
        types1[0] = 0;
        types1[1] = 0;
        types1[2] = 0;

        vm.startPrank(vaultOwner1);
        proxy1 = Vault(
            factory.createVault(
                uint256(
                    keccak256(
                        abi.encodeWithSignature(
                            "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                        )
                    )
                ),
                0,
                address(0)
            )
        );
        link.approve(address(proxy1), type(uint256).max);
        eth.approve(address(proxy1), type(uint256).max);
        safemoon.approve(address(proxy1), type(uint256).max);

        proxy1.deposit(tokens1, ids1, amounts1, types1);
        vm.stopPrank();

        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(link);
        tokens2[1] = address(eth);

        uint256[] memory ids2 = new uint256[](2);
        ids2[0] = 0;
        ids2[1] = 0;

        uint256[] memory amounts2 = new uint256[](2); // total value = 100_000 + 300_000, coll value = 200_000, liq value = 222_222.2222222
        amounts2[0] = 5_000 * 10 ** Constants.linkDecimals;
        amounts2[1] = 100 * 10 ** Constants.ethDecimals;

        uint256[] memory types2 = new uint256[](2);
        types2[0] = 0;
        types2[1] = 0;

        vm.startPrank(vaultOwner2);
        proxy2 = Vault(
            factory.createVault(
                uint256(
                    keccak256(
                        abi.encodeWithSignature(
                            "doRandom(uint256,uint256)", block.timestamp, block.number, blockhash(block.number)
                        )
                    )
                ),
                0,
                address(dai)
            )
        );
        link.approve(address(proxy2), type(uint256).max);
        eth.approve(address(proxy2), type(uint256).max);

        proxy2.deposit(tokens2, ids2, amounts2, types2);
        vm.stopPrank();

        // available margin proxy1 = 325k, minus fee (0.1%) = 324_675
        // available margin proxy2 = 200k = 199_800

        vm.startPrank(vaultOwner1);
        proxy1.openTrustedMarginAccount(address(pool));
        pool.borrow(
            449_550_449550449551 * 10 ** Constants.daiDecimals / 10 ** 12, address(proxy1), vaultOwner1, 0xae12fa
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner2);
        proxy2.openTrustedMarginAccount(address(pool));
        pool.borrow(199_800 * 10 ** Constants.daiDecimals, address(proxy2), vaultOwner2, 0xae12fb);
        vm.stopPrank();
    }

    function xtestLiquidationEndtoEnd() public {
        uint256 preValue = proxy1.getVaultValue(address(dai));
        uint256 preLiqValue = proxy1.getLiquidationValue();
        uint256 preColValue = proxy1.getCollateralValue();
        uint256 preUsedMargin = proxy1.getUsedMargin();
        uint256 preFreeMargin = proxy1.getFreeMargin();

        vm.prank(oracleOwner);
        oracleSafemoonToUsd.transmit(int256(0)); //oh no surprise

        uint256 postValue = proxy1.getVaultValue(address(dai));
        uint256 postLiqValue = proxy1.getLiquidationValue();
        uint256 postColValue = proxy1.getCollateralValue();
        uint256 postUsedMargin = proxy1.getUsedMargin();
        uint256 postFreeMargin = proxy1.getFreeMargin();

        emit log_named_uint("preValue", preValue);
        emit log_named_uint("preLiqValue", preLiqValue);
        emit log_named_uint("preColValue", preColValue);
        emit log_named_uint("preUsedMargin", preUsedMargin);
        emit log_named_uint("preFreeMargin", preFreeMargin);
        emit log_named_uint("postValue", postValue);
        emit log_named_uint("postLiqValue", postLiqValue);
        emit log_named_uint("postColValue", postColValue);
        emit log_named_uint("postUsedMargin", postUsedMargin);
        emit log_named_uint("postFreeMargin", postFreeMargin);

        // vault value =
        vm.prank(liquidationInitiator);
        pool.liquidateVault(address(proxy1));

        emit log_named_uint("total liq pre warp", pool.totalRealisedLiquidity());

        vm.warp(10 minutes);

        emit log_named_uint("total liq post warp", pool.totalRealisedLiquidity());

        (priceOfVault,) = liquidator.getPriceOfVault(address(proxy1));
        vm.prank(auctionBuyer);
        liquidator.buyVault(address(proxy1));

        emit log_named_uint("total liq post liq", pool.totalRealisedLiquidity());

        assertEq(pool.realisedLiquidityOf(liquidationInitiator), preUsedMargin * 2 / 100);
        assertEq(pool.totalRealisedLiquidity(), 2_200_000 + priceOfVault - preUsedMargin);
    }
}
