/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../../lib/forge-std/src/Test.sol";

import "../../Factory.sol";
import "../../Proxy.sol";
import { Vault, ActionData } from "../../Vault.sol";
import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";
import "../../mockups/ERC721SolmateMock.sol";
import "../../mockups/ERC1155SolmateMock.sol";
import "../../MainRegistry.sol";
import { PricingModule, StandardERC20PricingModule } from "../../PricingModules/StandardERC20PricingModule.sol";
import { FloorERC721PricingModule } from "../../PricingModules/FloorERC721PricingModule.sol";
import { FloorERC1155PricingModule } from "../../PricingModules/FloorERC1155PricingModule.sol";
import { Liquidator, LogExpMath } from "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";
import "../../mockups/ArcadiaOracle.sol";
import { RiskConstants } from "../../utils/RiskConstants.sol";
import ".././fixtures/ArcadiaOracleFixture.f.sol";

contract mainRegistryExtension is MainRegistry {
    using FixedPointMathLib for uint256;

    constructor(address factory_) MainRegistry(factory_) { }

    function setAssetType(address asset, uint96 assetType) public {
        assetToAssetInformation[asset].assetType = assetType;
    }
}

contract FactoryExtension is Factory {
    function setOwnerOf(address owner_, uint256 vaultId) public {
        _ownerOf[vaultId] = owner_;
    }
}

contract DeployArcadiaVaults is Test {
    FactoryExtension public factory;
    Vault public vault;
    Vault public proxy;
    address public proxyAddr;
    ERC20Mock public dai;
    ERC20Mock public eth;
    ERC20Mock public snx;
    ERC20Mock public link;
    ERC20Mock public safemoon;
    ERC721Mock public bayc;
    ERC721Mock public mayc;
    ERC721Mock public dickButs;
    ERC1155Mock public interleave;
    OracleHub public oracleHub;
    ArcadiaOracle public oracleDaiToUsd;
    ArcadiaOracle public oracleEthToUsd;
    ArcadiaOracle public oracleLinkToUsd;
    ArcadiaOracle public oracleSnxToEth;
    ArcadiaOracle public oracleBaycToEth;
    ArcadiaOracle public oracleMaycToUsd;
    ArcadiaOracle public oracleInterleaveToEth;
    mainRegistryExtension public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    FloorERC721PricingModule public floorERC721PricingModule;
    FloorERC1155PricingModule public floorERC1155PricingModule;
    Liquidator public liquidator;

    address public creatorAddress = address(1);
    address public tokenCreatorAddress = address(2);
    address public oracleOwner = address(3);
    address public unprivilegedAddress = address(4);
    address public vaultOwner = address(6);
    address public liquidityProvider = address(7);

    uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
    uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10 ** Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1_600_000_000_000_000;
    uint256 rateBaycToEth = 85 * 10 ** Constants.oracleBaycToEthDecimals;
    uint256 rateMaycToUsd = 50_000 * 10 ** Constants.oracleMaycToUsdDecimals;
    uint256 rateInterleaveToEth = 1 * 10 ** (Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleBaycToEthEthToUsd = new address[](2);
    address[] public oracleMaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    uint16 public collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 public liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    PricingModule.RiskVarInput[] emptyRiskVarInput;
    PricingModule.RiskVarInput[] riskVars;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        //Deploy and mint tokens
        vm.startPrank(tokenCreatorAddress);
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        dai.mint(liquidityProvider, type(uint256).max);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        eth.mint(tokenCreatorAddress, 200_000 * 10 ** Constants.ethDecimals);
        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        snx.mint(tokenCreatorAddress, 200_000 * 10 ** Constants.snxDecimals);
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );
        link.mint(tokenCreatorAddress, 200_000 * 10 ** Constants.linkDecimals);
        safemoon = new ERC20Mock(
            "Safemoon Mock",
            "mSFMN",
            uint8(Constants.safemoonDecimals)
        );
        safemoon.mint(tokenCreatorAddress, 200_000 * 10 ** Constants.safemoonDecimals);
        bayc = new ERC721Mock("BAYC Mock", "mBAYC");
        bayc.mint(tokenCreatorAddress, 0);
        bayc.mint(tokenCreatorAddress, 1);
        bayc.mint(tokenCreatorAddress, 2);
        bayc.mint(tokenCreatorAddress, 3);
        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        mayc.mint(tokenCreatorAddress, 0);
        dickButs = new ERC721Mock("DickButs Mock", "mDICK");
        dickButs.mint(tokenCreatorAddress, 0);
        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
        interleave.mint(tokenCreatorAddress, 1, 100_000);

        eth.transfer(vaultOwner, 100_000 * 10 ** Constants.ethDecimals);
        link.transfer(vaultOwner, 100_000 * 10 ** Constants.linkDecimals);
        snx.transfer(vaultOwner, 100_000 * 10 ** Constants.snxDecimals);
        safemoon.transfer(vaultOwner, 100_000 * 10 ** Constants.safemoonDecimals);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        dickButs.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        eth.transfer(unprivilegedAddress, 1000 * 10 ** Constants.ethDecimals);
        vm.stopPrank();

        //Deploi Oracles
        oracleDaiToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD");
        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleLinkToUsdDecimals), "LINK / USD");
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleSnxToEthDecimals), "SNX / ETH");
        oracleBaycToEth = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleBaycToEthDecimals), "BAYC / ETH");
        oracleMaycToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleMaycToUsdDecimals), "MAYC / USD");
        oracleInterleaveToEth =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleInterleaveToEthDecimals), "INTERLEAVE / ETH");

        oracleDaiToUsdArr[0] = address(oracleDaiToUsd);
        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        oracleLinkToUsdArr[0] = address(oracleLinkToUsd);
        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleBaycToEthEthToUsd[0] = address(oracleBaycToEth);
        oracleBaycToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleMaycToUsdArr[0] = address(oracleMaycToUsd);
        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);

        vm.startPrank(oracleOwner);
        oracleDaiToUsd.transmit(int256(rateDaiToUsd));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleBaycToEth.transmit(int256(rateBaycToEth));
        oracleMaycToUsd.transmit(int256(rateMaycToUsd));
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEth));
        vm.stopPrank();

        //Deploy Arcadia Vaults contracts
        vm.startPrank(creatorAddress);
        oracleHub = new OracleHub();
        factory = new FactoryExtension();

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleDaiToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "DAI",
                quoteAsset: "USD",
                oracle: address(oracleDaiToUsd),
                baseAssetAddress: address(dai),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "LINK",
                quoteAsset: "USD",
                oracle: address(oracleLinkToUsd),
                baseAssetAddress: address(link),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleBaycToEthUnit),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "BAYC",
                quoteAsset: "ETH",
                oracle: address(oracleBaycToEth),
                baseAssetAddress: address(bayc),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleMaycToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "MAYC",
                quoteAsset: "USD",
                oracle: address(oracleMaycToUsd),
                baseAssetAddress: address(mayc),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleInterleaveToEthUnit),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "INTERLEAVE",
                quoteAsset: "ETH",
                oracle: address(oracleInterleaveToEth),
                baseAssetAddress: address(interleave),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        mainRegistry = new mainRegistryExtension(address(factory));
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub),
            0
        );
        floorERC721PricingModule = new FloorERC721PricingModule(
            address(mainRegistry),
            address(oracleHub),
            1
        );
        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistry),
            address(oracleHub),
            2
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        mainRegistry.addPricingModule(address(floorERC1155PricingModule));

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

        standardERC20PricingModule.addAsset(address(dai), oracleDaiToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, riskVars_, type(uint128).max);

        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleBaycToEthEthToUsd, riskVars_, type(uint128).max
        );
        floorERC721PricingModule.addAsset(
            address(mayc), 0, type(uint256).max, oracleMaycToUsdArr, riskVars_, type(uint128).max
        );

        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, riskVars_, type(uint128).max
        );

        vault = new Vault();
        factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }
}
