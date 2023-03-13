/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {
    DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsOptimism
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

contract ArcadiaVaultDeployerOptimism is Test {
    Factory public factory;
    Vault public vault;

    ERC20 public dai;
    ERC20 public frax;
    ERC20 public snx;
    ERC20 public usdc;
    ERC20 public usdt;
    ERC20 public wbtc;
    ERC20 public weth;
    ERC20 public wsteth;
    ERC20 public op;

    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    Liquidator public liquidator;
    ActionMultiCall public actionMultiCall;

    LendingPool public wethLendingPool = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);
    LendingPool public usdcLendingPool = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleFraxToUsdArr = new address[](1);
    address[] public oracleSnxToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleUsdtToUsdArr = new address[](1);
    address[] public oracleWbtcToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleWstethToUsdArr = new address[](1);
    address[] public oracleOpToUsdArr = new address[](1);

    PricingModule.RiskVarInput[] public riskVarsDai;
    PricingModule.RiskVarInput[] public riskVarsFrax;
    PricingModule.RiskVarInput[] public riskVarsSnx;
    PricingModule.RiskVarInput[] public riskVarsUsdc;
    PricingModule.RiskVarInput[] public riskVarsUsdt;
    PricingModule.RiskVarInput[] public riskVarsWbtc;
    PricingModule.RiskVarInput[] public riskVarsWeth;
    PricingModule.RiskVarInput[] public riskVarsWsteth;
    PricingModule.RiskVarInput[] public riskVarsOp;

    OracleHub.OracleInformation public daiToUsdOracleInfo;
    OracleHub.OracleInformation public fraxToUsdOracleInfo;
    OracleHub.OracleInformation public snxToUsdOracleInfo;
    OracleHub.OracleInformation public usdcToUsdOracleInfo;
    OracleHub.OracleInformation public usdtToUsdOracleInfo;
    OracleHub.OracleInformation public wbtcToUsdOracleInfo;
    OracleHub.OracleInformation public ethToUsdOracleInfo;
    OracleHub.OracleInformation public wstethToUsdOracleInfo;
    OracleHub.OracleInformation public opToUsdOracleInfo;

    MainRegistry.BaseCurrencyInformation public usdBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public ethBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public usdcBaseCurrencyInfo;

    constructor() {
        /*///////////////////////////////////////////////////////////////
                          ADDRESSES
        ///////////////////////////////////////////////////////////////*/

        dai = ERC20(DeployAddresses.dai_optimism);
        frax = ERC20(DeployAddresses.frax_optimism);
        snx = ERC20(DeployAddresses.snx_optimism);
        usdc = ERC20(DeployAddresses.usdc_optimism);
        usdt = ERC20(DeployAddresses.usdt_optimism);
        wbtc = ERC20(DeployAddresses.wbtc_optimism);
        weth = ERC20(DeployAddresses.weth_optimism);
        wsteth = ERC20(DeployAddresses.wsteth_optimism);
        op = ERC20(DeployAddresses.op_optimism);

        /*///////////////////////////////////////////////////////////////
                          ORACLE TRAINS
        ///////////////////////////////////////////////////////////////*/

        oracleDaiToUsdArr[0] = DeployAddresses.oracleDaiToUsd_optimism;
        oracleFraxToUsdArr[0] = DeployAddresses.oracleFraxToUsd_optimism;
        oracleSnxToUsdArr[0] = DeployAddresses.oracleSnxToUsd_optimism;
        oracleUsdcToUsdArr[0] = DeployAddresses.oracleUsdcToUsd_optimism;
        oracleUsdtToUsdArr[0] = DeployAddresses.oracleUsdtToUsd_optimism;
        oracleWbtcToUsdArr[0] = DeployAddresses.oracleWbtcToUsd_optimism;
        oracleEthToUsdArr[0] = DeployAddresses.oracleEthToUsd_optimism;
        oracleWstethToUsdArr[0] = DeployAddresses.oracleWstethToUsd_optimism;
        oracleOpToUsdArr[0] = DeployAddresses.oracleOpToUsd_optimism;

        /*///////////////////////////////////////////////////////////////
                          ORACLE INFO
        ///////////////////////////////////////////////////////////////*/

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd_optimism,
            baseAssetAddress: DeployAddresses.dai_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        fraxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleFraxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "FRAX",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleFraxToUsd_optimism,
            baseAssetAddress: DeployAddresses.frax_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        snxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleSnxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "SNX",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleSnxToUsd_optimism,
            baseAssetAddress: DeployAddresses.snx_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd_optimism,
            baseAssetAddress: DeployAddresses.usdc_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdtToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdtToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDT",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdtToUsd_optimism,
            baseAssetAddress: DeployAddresses.usdt_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        wbtcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleWbtcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "wBTC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleWbtcToUsd_optimism,
            baseAssetAddress: DeployAddresses.wbtc_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "wETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd_optimism,
            baseAssetAddress: DeployAddresses.weth_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        wstethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleWstethToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "wstETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleWstethToUsd_optimism,
            baseAssetAddress: DeployAddresses.wsteth_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        opToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleOpToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "OP",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleOpToUsd_optimism,
            baseAssetAddress: DeployAddresses.op_optimism,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: DeployAddresses.weth_optimism,
            baseCurrencyToUsdOracle: DeployAddresses.oracleEthToUsd_optimism,
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.wethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: DeployAddresses.usdc_optimism,
            baseCurrencyToUsdOracle: DeployAddresses.oracleUsdcToUsd_optimism,
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

        /*///////////////////////////////////////////////////////////////
                            RISK VARS
        ///////////////////////////////////////////////////////////////*/

        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.dai_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.dai_liqFact_1
            })
        );
        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.dai_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.dai_liqFact_2
            })
        );

        riskVarsFrax.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.frax_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.frax_liqFact_1
            })
        );
        riskVarsFrax.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.frax_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.frax_liqFact_2
            })
        );

        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.snx_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.snx_liqFact_1
            })
        );
        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.snx_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.snx_liqFact_2
            })
        );

        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.usdc_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.usdc_liqFact_1
            })
        );
        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.usdc_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.usdc_liqFact_2
            })
        );

        riskVarsUsdt.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.usdt_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.usdt_liqFact_1
            })
        );
        riskVarsUsdt.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.usdt_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.usdt_liqFact_2
            })
        );

        riskVarsWbtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.wbtc_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.wbtc_liqFact_1
            })
        );
        riskVarsWbtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.wbtc_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.wbtc_liqFact_2
            })
        );

        riskVarsWeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.weth_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.weth_liqFact_1
            })
        );
        riskVarsWeth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.weth_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.weth_liqFact_2
            })
        );

        riskVarsWsteth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.wsteth_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.wsteth_liqFact_1
            })
        );
        riskVarsWsteth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.wsteth_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.wsteth_liqFact_2
            })
        );

        riskVarsOp.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.op_collFact_1,
                liquidationFactor: DeployRiskConstantsOptimism.op_liqFact_1
            })
        );
        riskVarsOp.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsOptimism.op_collFact_2,
                liquidationFactor: DeployRiskConstantsOptimism.op_liqFact_2
            })
        );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_OPTIMISM");

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

        oracleHub.addOracle(daiToUsdOracleInfo);
        oracleHub.addOracle(fraxToUsdOracleInfo);
        oracleHub.addOracle(snxToUsdOracleInfo);
        oracleHub.addOracle(usdcToUsdOracleInfo);
        oracleHub.addOracle(usdtToUsdOracleInfo);
        oracleHub.addOracle(wbtcToUsdOracleInfo);
        oracleHub.addOracle(ethToUsdOracleInfo);
        oracleHub.addOracle(wstethToUsdOracleInfo);
        oracleHub.addOracle(opToUsdOracleInfo);

        mainRegistry.addBaseCurrency(ethBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(usdcBaseCurrencyInfo);

        mainRegistry.addPricingModule(address(standardERC20PricingModule));

        PricingModule.RiskVarInput[] memory riskVarsDai_ = riskVarsDai;
        PricingModule.RiskVarInput[] memory riskVarsFrax_ = riskVarsFrax;
        PricingModule.RiskVarInput[] memory riskVarsSnx_ = riskVarsSnx;
        PricingModule.RiskVarInput[] memory riskVarsUsdc_ = riskVarsUsdc;
        PricingModule.RiskVarInput[] memory riskVarsUsdt_ = riskVarsUsdt;
        PricingModule.RiskVarInput[] memory riskVarsWbtc_ = riskVarsWbtc;
        PricingModule.RiskVarInput[] memory riskVarsWeth_ = riskVarsWeth;
        PricingModule.RiskVarInput[] memory riskVarsWsteth_ = riskVarsWsteth;
        PricingModule.RiskVarInput[] memory riskVarsOp_ = riskVarsOp;

        standardERC20PricingModule.addAsset(
            DeployAddresses.dai_optimism, oracleDaiToUsdArr, riskVarsDai_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.frax_optimism, oracleFraxToUsdArr, riskVarsFrax_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.snx_optimism, oracleSnxToUsdArr, riskVarsSnx_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.usdc_optimism, oracleUsdcToUsdArr, riskVarsUsdc_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.usdt_optimism, oracleUsdtToUsdArr, riskVarsUsdt_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.wbtc_optimism, oracleWbtcToUsdArr, riskVarsWbtc_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.weth_optimism, oracleEthToUsdArr, riskVarsWeth_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.wsteth_optimism, oracleWstethToUsdArr, riskVarsWsteth_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.op_optimism, oracleOpToUsdArr, riskVarsOp_, type(uint128).max
        );

        factory.setNewVaultInfo(address(mainRegistry), address(vault), DeployBytes.upgradeRoot1To1, "");

        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        wethLendingPool.setVaultVersion(1, true);
        usdcLendingPool.setVaultVersion(1, true);

        wethLendingPool.setBorrowCap(50 * 10**18);
        usdcLendingPool.setBorrowCap(75000 * 10**6);

        vm.stopBroadcast();
    }
}
