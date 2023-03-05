/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployBytes } from "./Constants/DeployConstants.sol";

import "../src/Factory.sol";
import "../src/Proxy.sol";
import "../src/Vault.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import "../src/MainRegistry.sol";
import { PricingModule, StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import "../src/Liquidator.sol";
import "../src/OracleHub.sol";
import { RiskConstants } from "../src/utils/RiskConstants.sol";

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
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd,
            baseAssetAddress: DeployAddresses.dai,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "ETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd,
            baseAssetAddress: DeployAddresses.eth,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        linkToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleLinkToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "LINK",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleLinkToEth,
            baseAssetAddress: DeployAddresses.link,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        snxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleSnxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "SNX",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleSnxToUsd,
            baseAssetAddress: DeployAddresses.snx,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd,
            baseAssetAddress: DeployAddresses.usdc,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        btcToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleBtcToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "BTC",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleBtcToEth,
            baseAssetAddress: DeployAddresses.btc,
            quoteAssetIsBaseCurrency: true,
            isActive: true
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
            assetAddress: DeployAddresses.usdc,
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

        mainRegistry = new MainRegistry(address(factory));
        mainRegistry.addBaseCurrency(ethBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(usdcBaseCurrencyInfo);

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub),
            0
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

        vault = new Vault(address(mainRegistry), 1);
        factory.setNewVaultInfo(address(mainRegistry), address(vault), DeployBytes.upgradeRoot1To1, "");

        vm.stopBroadcast();
    }
}
