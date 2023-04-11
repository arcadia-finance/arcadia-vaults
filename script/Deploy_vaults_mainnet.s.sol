/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {
    DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsMainnet
} from "./Constants/DeployConstants.sol";

import { Factory } from "../src/Factory.sol";
import { Proxy } from "../src/Proxy.sol";
import { Vault } from "../src/Vault.sol";
import { MainRegistry } from "../src/MainRegistry.sol";
import { PricingModule, StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { RiskConstants } from "../src/utils/RiskConstants.sol";

import { ActionMultiCall } from "../src/actions/MultiCall.sol";

import { ERC20 } from "../lib/arcadia-lending/src/DebtToken.sol";
import { LendingPool } from "../lib/arcadia-lending/src/LendingPool.sol";

contract ArcadiaVaultDeployerMainnet is Test {
    Factory public factory;
    Vault public vault;

    ERC20 public crv;
    ERC20 public dai;
    ERC20 public frax;
    ERC20 public fxs;
    ERC20 public link;
    ERC20 public snx;
    ERC20 public uni;
    ERC20 public usdc;
    ERC20 public usdt;
    ERC20 public wbtc;
    ERC20 public weth;
    ERC20 public cbeth;

    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    Liquidator public liquidator;
    ActionMultiCall public actionMultiCall;

    LendingPool public wethLendingPool = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);
    LendingPool public usdcLendingPool = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

    address[] public oracleCrvToUsdArr = new address[](1);
    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleFraxToUsdArr = new address[](1);
    address[] public oracleFxsToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToUsdArr = new address[](1);
    address[] public oracleUniToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleUsdtToUsdArr = new address[](1);
    address[] public oracleWbtcToBtcToUsdArr = new address[](2);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleCbethToEthToUsdArr = new address[](2);

    PricingModule.RiskVarInput[] public riskVarsCrv;
    PricingModule.RiskVarInput[] public riskVarsDai;
    PricingModule.RiskVarInput[] public riskVarsFrax;
    PricingModule.RiskVarInput[] public riskVarsFxs;
    PricingModule.RiskVarInput[] public riskVarsLink;
    PricingModule.RiskVarInput[] public riskVarsSnx;
    PricingModule.RiskVarInput[] public riskVarsUni;
    PricingModule.RiskVarInput[] public riskVarsUsdc;
    PricingModule.RiskVarInput[] public riskVarsUsdt;
    PricingModule.RiskVarInput[] public riskVarsWbtc;
    PricingModule.RiskVarInput[] public riskVarsWeth;
    PricingModule.RiskVarInput[] public riskVarsCbeth;

    OracleHub.OracleInformation public crvToUsdOracleInfo;
    OracleHub.OracleInformation public daiToUsdOracleInfo;
    OracleHub.OracleInformation public fraxToUsdOracleInfo;
    OracleHub.OracleInformation public fxsToUsdOracleInfo;
    OracleHub.OracleInformation public linkToUsdOracleInfo;
    OracleHub.OracleInformation public snxToUsdOracleInfo;
    OracleHub.OracleInformation public uniToUsdOracleInfo;
    OracleHub.OracleInformation public usdcToUsdOracleInfo;
    OracleHub.OracleInformation public usdtToUsdOracleInfo;
    OracleHub.OracleInformation public wbtcToBtcOracleInfo;
    OracleHub.OracleInformation public btcToUsdOracleInfo;
    OracleHub.OracleInformation public ethToUsdOracleInfo;
    OracleHub.OracleInformation public cbethToEthOracleInfo;

    MainRegistry.BaseCurrencyInformation public usdBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public ethBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public usdcBaseCurrencyInfo;

    constructor() {
        /*///////////////////////////////////////////////////////////////
                          ADDRESSES
        ///////////////////////////////////////////////////////////////*/

        crv = ERC20(DeployAddresses.crv_mainnet);
        dai = ERC20(DeployAddresses.dai_mainnet);
        frax = ERC20(DeployAddresses.frax_mainnet);
        fxs = ERC20(DeployAddresses.fxs_mainnet);
        link = ERC20(DeployAddresses.link_mainnet);
        snx = ERC20(DeployAddresses.snx_mainnet);
        uni = ERC20(DeployAddresses.uni_mainnet);
        usdc = ERC20(DeployAddresses.usdc_mainnet);
        usdt = ERC20(DeployAddresses.usdt_mainnet);
        wbtc = ERC20(DeployAddresses.wbtc_mainnet);
        weth = ERC20(DeployAddresses.weth_mainnet);
        cbeth = ERC20(DeployAddresses.cbeth_mainnet);

        /*///////////////////////////////////////////////////////////////
                          ORACLE TRAINS
        ///////////////////////////////////////////////////////////////*/

        oracleCrvToUsdArr[0] = DeployAddresses.oracleCrvToUsd_mainnet;
        oracleDaiToUsdArr[0] = DeployAddresses.oracleDaiToUsd_mainnet;
        oracleFraxToUsdArr[0] = DeployAddresses.oracleFraxToUsd_mainnet;
        oracleFxsToUsdArr[0] = DeployAddresses.oracleFxsToUsd_mainnet;
        oracleLinkToUsdArr[0] = DeployAddresses.oracleLinkToUsd_mainnet;
        oracleSnxToUsdArr[0] = DeployAddresses.oracleSnxToUsd_mainnet;
        oracleUniToUsdArr[0] = DeployAddresses.oracleUniToUsd_mainnet;
        oracleUsdcToUsdArr[0] = DeployAddresses.oracleUsdcToUsd_mainnet;
        oracleUsdtToUsdArr[0] = DeployAddresses.oracleUsdtToUsd_mainnet;
        oracleWbtcToBtcToUsdArr[0] = DeployAddresses.oracleWbtcToBtc_mainnet;
        oracleWbtcToBtcToUsdArr[1] = DeployAddresses.oracleBtcToUsd_mainnet;
        oracleEthToUsdArr[0] = DeployAddresses.oracleEthToUsd_mainnet;
        oracleCbethToEthToUsdArr[0] = DeployAddresses.oracleCbethToEth_mainnet;
        oracleCbethToEthToUsdArr[1] = DeployAddresses.oracleEthToUsd_mainnet;

        /*///////////////////////////////////////////////////////////////
                          ORACLE INFO
        ///////////////////////////////////////////////////////////////*/

        crvToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleCrvToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "CRV",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleCrvToUsd_mainnet,
            baseAssetAddress: DeployAddresses.crv_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd_mainnet,
            baseAssetAddress: DeployAddresses.dai_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        fraxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleFraxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "FRAX",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleFraxToUsd_mainnet,
            baseAssetAddress: DeployAddresses.frax_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        fxsToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleFxsToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "FXS",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleFxsToUsd_mainnet,
            baseAssetAddress: DeployAddresses.fxs_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        linkToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleLinkToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "LINK",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleLinkToUsd_mainnet,
            baseAssetAddress: DeployAddresses.link_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        snxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleSnxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "SNX",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleSnxToUsd_mainnet,
            baseAssetAddress: DeployAddresses.snx_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        uniToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUniToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "UNI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUniToUsd_mainnet,
            baseAssetAddress: DeployAddresses.uni_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd_mainnet,
            baseAssetAddress: DeployAddresses.usdc_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdtToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdtToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDT",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdtToUsd_mainnet,
            baseAssetAddress: DeployAddresses.usdt_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        wbtcToBtcOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleWbtcToBtcUnit),
            quoteAssetBaseCurrency: uint8(0),
            baseAsset: "wBTC",
            quoteAsset: "BTC",
            oracle: DeployAddresses.oracleWbtcToBtc_mainnet,
            baseAssetAddress: DeployAddresses.wbtc_mainnet,
            quoteAssetIsBaseCurrency: false,
            isActive: true
        });

        btcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleBtcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "BTC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleBtcToUsd_mainnet,
            baseAssetAddress: address(0),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "wETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd_mainnet,
            baseAssetAddress: DeployAddresses.weth_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        cbethToEthOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleCbethToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "cbETH",
            quoteAsset: "wETH",
            oracle: DeployAddresses.oracleCbethToEth_mainnet,
            baseAssetAddress: DeployAddresses.cbeth_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: DeployAddresses.weth_mainnet,
            baseCurrencyToUsdOracle: DeployAddresses.oracleEthToUsd_mainnet,
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.wethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: DeployAddresses.usdc_mainnet,
            baseCurrencyToUsdOracle: DeployAddresses.oracleUsdcToUsd_mainnet,
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

        /*///////////////////////////////////////////////////////////////
                            RISK VARS
        ///////////////////////////////////////////////////////////////*/

        riskVarsCrv.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.crv_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.crv_liqFact_1
            })
        );
        riskVarsCrv.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.crv_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.crv_liqFact_2
            })
        );

        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.dai_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.dai_liqFact_1
            })
        );
        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.dai_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.dai_liqFact_2
            })
        );

        riskVarsFrax.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.frax_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.frax_liqFact_1
            })
        );
        riskVarsFrax.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.frax_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.frax_liqFact_2
            })
        );

        riskVarsFxs.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.fxs_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.fxs_liqFact_1
            })
        );
        riskVarsFxs.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.fxs_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.fxs_liqFact_2
            })
        );

        riskVarsLink.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.link_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.link_liqFact_1
            })
        );
        riskVarsLink.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.link_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.link_liqFact_2
            })
        );

        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.snx_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.snx_liqFact_1
            })
        );
        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.snx_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.snx_liqFact_2
            })
        );

        riskVarsUni.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.uni_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.uni_liqFact_1
            })
        );
        riskVarsUni.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.uni_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.uni_liqFact_2
            })
        );

        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.usdc_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.usdc_liqFact_1
            })
        );
        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.usdc_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.usdc_liqFact_2
            })
        );

        riskVarsUsdt.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.usdt_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.usdt_liqFact_1
            })
        );
        riskVarsUsdt.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.usdt_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.usdt_liqFact_2
            })
        );

        riskVarsWbtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.wbtc_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.wbtc_liqFact_1
            })
        );
        riskVarsWbtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.wbtc_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.wbtc_liqFact_2
            })
        );

        riskVarsWeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.weth_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.weth_liqFact_1
            })
        );
        riskVarsWeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.weth_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.weth_liqFact_2
            })
        );

        riskVarsCbeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.cbeth_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.cbeth_liqFact_1
            })
        );
        riskVarsCbeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.cbeth_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.cbeth_liqFact_2
            })
        );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_MAINNET");

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x00CB53780Ea58503D3059FC02dDd596D0Be926cB);
        liquidator = Liquidator(0xD2A34731586bD10B645f870f4C9DcAF4F9e3823C);

        mainRegistry = new MainRegistry(address(factory));
        oracleHub = new OracleHub();
        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub),
            0
        );

        vault = new Vault();
        actionMultiCall = new ActionMultiCall();

        oracleHub.addOracle(crvToUsdOracleInfo);
        oracleHub.addOracle(daiToUsdOracleInfo);
        oracleHub.addOracle(fraxToUsdOracleInfo);
        oracleHub.addOracle(fxsToUsdOracleInfo);
        oracleHub.addOracle(linkToUsdOracleInfo);
        oracleHub.addOracle(snxToUsdOracleInfo);
        oracleHub.addOracle(uniToUsdOracleInfo);
        oracleHub.addOracle(usdcToUsdOracleInfo);
        oracleHub.addOracle(usdtToUsdOracleInfo);
        oracleHub.addOracle(wbtcToBtcOracleInfo);
        oracleHub.addOracle(btcToUsdOracleInfo);
        oracleHub.addOracle(ethToUsdOracleInfo);
        oracleHub.addOracle(cbethToEthOracleInfo);

        mainRegistry.addBaseCurrency(ethBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(usdcBaseCurrencyInfo);

        mainRegistry.addPricingModule(address(standardERC20PricingModule));

        PricingModule.RiskVarInput[] memory riskVarsCrv_ = riskVarsCrv;
        PricingModule.RiskVarInput[] memory riskVarsDai_ = riskVarsDai;
        PricingModule.RiskVarInput[] memory riskVarsFrax_ = riskVarsFrax;
        PricingModule.RiskVarInput[] memory riskVarsFxs_ = riskVarsFxs;
        PricingModule.RiskVarInput[] memory riskVarsLink_ = riskVarsLink;
        PricingModule.RiskVarInput[] memory riskVarsSnx_ = riskVarsSnx;
        PricingModule.RiskVarInput[] memory riskVarsUni_ = riskVarsUni;
        PricingModule.RiskVarInput[] memory riskVarsUsdc_ = riskVarsUsdc;
        PricingModule.RiskVarInput[] memory riskVarsUsdt_ = riskVarsUsdt;
        PricingModule.RiskVarInput[] memory riskVarsWbtc_ = riskVarsWbtc;
        PricingModule.RiskVarInput[] memory riskVarsWeth_ = riskVarsWeth;
        PricingModule.RiskVarInput[] memory riskVarsCbeth_ = riskVarsCbeth;

        standardERC20PricingModule.addAsset(
            DeployAddresses.crv_mainnet, oracleCrvToUsdArr, riskVarsCrv_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.dai_mainnet, oracleDaiToUsdArr, riskVarsDai_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.frax_mainnet, oracleFraxToUsdArr, riskVarsFrax_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.fxs_mainnet, oracleFxsToUsdArr, riskVarsFxs_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.link_mainnet, oracleLinkToUsdArr, riskVarsLink_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.snx_mainnet, oracleSnxToUsdArr, riskVarsSnx_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.uni_mainnet, oracleUniToUsdArr, riskVarsUni_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.usdc_mainnet, oracleUsdcToUsdArr, riskVarsUsdc_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.usdt_mainnet, oracleUsdtToUsdArr, riskVarsUsdt_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.wbtc_mainnet, oracleWbtcToBtcToUsdArr, riskVarsWbtc_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.weth_mainnet, oracleEthToUsdArr, riskVarsWeth_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.cbeth_mainnet, oracleCbethToEthToUsdArr, riskVarsCbeth_, type(uint128).max
        );

        factory.setNewVaultInfo(address(mainRegistry), address(vault), DeployBytes.upgradeRoot1To1, "");

        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        wethLendingPool.setVaultVersion(1, true);
        usdcLendingPool.setVaultVersion(1, true);

        // wethLendingPool.setBorrowCap(50 * 10**18);
        // usdcLendingPool.setBorrowCap(75000 * 10**6);
        wethLendingPool.setBorrowCap(0);
        usdcLendingPool.setBorrowCap(0);

        vm.stopBroadcast();
    }
}
