/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {DeployAddresses, DeployNumbers, DeployBytes} from "./Constants/DeployConstants.sol";

import "../src/Factory.sol";
import "../src/Proxy.sol";
import "../src/Vault.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import "../src/AssetRegistry/MainRegistry.sol";
import "../src/AssetRegistry/StandardERC20PricingModule.sol";
import "../src/Liquidator.sol";
import "../src/OracleHub.sol";

contract ArcadiaVaultDeployer is Test {
    Factory public factory;
    Vault public vault;
    Vault public proxy;
    address public proxyAddr;
    ERC20 public dai;
    ERC20 public eth;
    ERC20 public link;
    ERC20 public snx;
    ERC20 public usdc;
    ERC20 public btc;
    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    Liquidator public liquidator;

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToEthEthToUsdArr = new address[](2);
    address[] public oracleSnxToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleBtcToEthEthToUsdArr = new address[](2);

    uint16 public collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 public liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    PricingModule.RiskVarInput[] public riskVars;

    OracleHub.OracleInformation public daiToUsdOracleInfo;
    OracleHub.OracleInformation public ethToUsdOracleInfo;
    OracleHub.OracleInformation public linkToEthEthToUsdOracleInfo;
    OracleHub.OracleInformation public snxToUsdOracleInfo;
    OracleHub.OracleInformation public usdcToUsdOracleInfo;
    OracleHub.OracleInformation public btcToEthEthToUsdOracleInfo;

    MainRegistry.BaseCurrencyInformation public usdBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public ethBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public usdcBaseCurrencyInfo;

    constructor() {
        dai = ERC20(DeployAddresses.dai);
        eth = ERC20(DeployAddresses.eth);
        link = ERC20(DeployAddresses.link);
        snx = ERC20(DeployAddresses.snx);
        usdc = ERC20(DeployAddresses.usdc);
        btc = ERC20(DeployAddresses.btc);

        oracleDaiToUsdArr[0] = DeployAddresses.oracleDaiToUsd;
        oracleEthToUsdArr[0] = DeployAddresses.oracleEthToUsd;
        oracleLinkToEthEthToUsdArr[0] = DeployAddresses.oracleLinkToEth;
        oracleLinkToEthEthToUsdArr[1] = DeployAddresses.oracleEthToUsd;
        oracleSnxToUsdArr[0] = DeployAddresses.oracleSnxToUsd;
        oracleUsdcToUsdArr[0] = DeployAddresses.oracleUsdcToUsd;
        oracleBtcToEthEthToUsdArr[0] = DeployAddresses.oracleBtcToEth;
        oracleBtcToEthEthToUsdArr[1] = DeployAddresses.oracleEthToUsd;

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            quoteAsset: "DAI",
            baseAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd,
            quoteAssetAddress: DeployAddresses.dai,
            baseAssetIsBaseCurrency: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            quoteAsset: "ETH",
            baseAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd,
            quoteAssetAddress: DeployAddresses.eth,
            baseAssetIsBaseCurrency: true
        });

        linkToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleLinkToEthUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            quoteAsset: "LINK",
            baseAsset: "ETH",
            oracle: DeployAddresses.oracleLinkToEth,
            quoteAssetAddress: DeployAddresses.link,
            baseAssetIsBaseCurrency: true
        });

        snxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleSnxToUsdUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            quoteAsset: "SNX",
            baseAsset: "USD",
            oracle: DeployAddresses.oracleSnxToUsd,
            quoteAssetAddress: DeployAddresses.snx,
            baseAssetIsBaseCurrency: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            quoteAsset: "USDC",
            baseAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd,
            quoteAssetAddress: DeployAddresses.usdc,
            baseAssetIsBaseCurrency: true
        });

        btcToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleBtcToEthUnit),
            baseAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            quoteAsset: "BTC",
            baseAsset: "ETH",
            oracle: DeployAddresses.oracleBtcToEth,
            quoteAssetAddress: DeployAddresses.btc,
            baseAssetIsBaseCurrency: true
        });

        usdBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: 0,
            assetAddress: 0x0000000000000000000000000000000000000000,
            baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
            baseCurrencyLabel: "USD",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdDecimals))
        });

        ethBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: DeployAddresses.eth,
            baseCurrencyToUsdOracle: address(DeployAddresses.oracleEthToUsd),
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.ethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: DeployAddresses.eth,
            baseCurrencyToUsdOracle: address(DeployAddresses.oracleUsdcToUsd),
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

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
    }

    function testDeploy_script() public {
        run();

        emit log_named_address("oracleHub", address(oracleHub));
        emit log_named_address("factory", address(factory));
        emit log_named_address("mainRegistry", address(mainRegistry));
        emit log_named_address("standardERC20PricingModule", address(standardERC20PricingModule));
        emit log_named_address("vaultLogic", address(vault));

    }

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        oracleHub = new OracleHub();

        factory = new Factory();

        oracleHub.addOracle(daiToUsdOracleInfo);
        oracleHub.addOracle(ethToUsdOracleInfo);
        oracleHub.addOracle(linkToEthEthToUsdOracleInfo);
        oracleHub.addOracle(snxToUsdOracleInfo);
        oracleHub.addOracle(usdcToUsdOracleInfo);
        oracleHub.addOracle(btcToEthEthToUsdOracleInfo);

        mainRegistry = new MainRegistry(usdBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(ethBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(usdcBaseCurrencyInfo);

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));

        PricingModule.RiskVarInput[] memory riskVars_ = riskVars;

        standardERC20PricingModule.addAsset(DeployAddresses.dai, oracleDaiToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(DeployAddresses.eth, oracleEthToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(
            DeployAddresses.link, oracleLinkToEthEthToUsdArr, riskVars_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(DeployAddresses.snx, oracleSnxToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(DeployAddresses.usdc, oracleUsdcToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(
            DeployAddresses.btc, oracleBtcToEthEthToUsdArr, riskVars_, type(uint128).max
        );

        vault = new Vault();
        factory.setNewVaultInfo(address(mainRegistry), address(vault), DeployBytes.upgradeRoot1To1);
        factory.confirmNewVaultInfo();
        mainRegistry.setFactory(address(factory));

        vm.stopBroadcast();
    }
}
