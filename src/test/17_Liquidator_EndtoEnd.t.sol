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

abstract contract LiquidatorEndToEnd is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ERC20Mock public usdc;

    LendingPool public pool;
    Tranche public SrTranche;
    Tranche public JrTranche;

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

    constructor() DeployArcadiaVaults() {
        vm.startPrank(liquidityProvider);
        dai.transfer(liqProviderSr1, 1_000_000 * Constants.daiDecimals);
        dai.transfer(liqProviderSr2, 1_000_000 * Constants.daiDecimals);
        dai.transfer(liqProviderJr1, 1_000_000 * Constants.daiDecimals);
        dai.transfer(liqProviderJr2, 1_000_000 * Constants.daiDecimals);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(
            address(factory),
            address(mainRegistry)
        );
        liquidator.setFactory(address(factory));

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
        vm.stopPrank();

        vm.startPrank(liqProviderSr1);
        dai.approve(address(pool), type(uint256).max);
        SrTranche.deposit(1_000_000 * Constants.daiDecimals, liqProviderSr1);
        vm.stopPrank();

        vm.startPrank(liqProviderSr2);
        dai.approve(address(pool), type(uint256).max);
        SrTranche.deposit(100_000 * Constants.daiDecimals, liqProviderSr2);
        vm.stopPrank();

        vm.startPrank(liqProviderJr1);
        dai.approve(address(pool), type(uint256).max);
        JrTranche.deposit(1_000_000 * Constants.daiDecimals, liqProviderJr1);
        vm.stopPrank();

        vm.startPrank(liqProviderJr2);
        dai.approve(address(pool), type(uint256).max);
        JrTranche.deposit(100_000 * Constants.daiDecimals, liqProviderJr2);
        vm.stopPrank();

        vm.prank(vaultOwner1);
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

        vm.prank(vaultOwner2);
        proxy2 = Vault(
            factory.createVault(
                uint256(
                    keccak256(
                        abi.encodeWithSignature(
                            "doRandom(uint256,uint256,bytes32)",
                            block.timestamp + 1,
                            block.number,
                            blockhash(block.number)
                        )
                    )
                ),
                0,
                address(0)
            )
        );
    }

    //this is a before each
    function setUp() public virtual {
        vm.startPrank(vaultOwner);
        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(pool), type(uint256).max);
        dai.approve(address(proxy), type(uint256).max);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        vm.stopPrank();
    }
}
