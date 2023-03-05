/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstants } from "./Constants/DeployConstants.sol";

import { Factory } from "../src/Factory.sol";
import { Proxy } from "../src/Proxy.sol";
import { Vault } from "../src/Vault.sol";
import { MainRegistry } from "../src/MainRegistry.sol";
import { PricingModule, StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { RiskConstants } from "../src/utils/RiskConstants.sol";

import { ActionMultiCall } from "../src/actions/MultiCall.sol";
import { DataTypes } from "../lib/arcadia-lending/src/libraries/DataTypes.sol";

import { ERC20, DebtToken } from "../lib/arcadia-lending/src/DebtToken.sol";
import { LendingPool } from "../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../lib/arcadia-lending/src/Tranche.sol";
import { TrustedCreditor } from "../lib/arcadia-lending/src/TrustedCreditor.sol";

contract ArcadiaVaultDeployer is Test {
    Factory public factory;
    Vault public vault;
    Vault public proxy_weth;
    Vault public proxy_usdc;
    address public proxyAddr;
    ERC20 public dai;
    ERC20 public weth;
    ERC20 public link;
    ERC20 public snx;
    ERC20 public usdc;
    ERC20 public btc;
    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    Liquidator public liquidator;
    ActionMultiCall public actionMultiCall;

    LendingPool public pool_weth;
    Tranche public srTranche_weth;
    Tranche public jrTranche_weth;

    LendingPool public pool_usdc;
    Tranche public srTranche_usdc;
    Tranche public jrTranche_usdc;

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToEthEthToUsdArr = new address[](2);
    address[] public oracleSnxToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleBtcToEthEthToUsdArr = new address[](2);

    uint16 public collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 public liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    PricingModule.RiskVarInput[] public riskVarsDai;
    PricingModule.RiskVarInput[] public riskVarsEth;
    PricingModule.RiskVarInput[] public riskVarsLink;
    PricingModule.RiskVarInput[] public riskVarsSnx;
    PricingModule.RiskVarInput[] public riskVarsUsdc;
    PricingModule.RiskVarInput[] public riskVarsBtc;

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
        dai = ERC20(vm.envAddress("dai_mainnet"));
        weth = ERC20(vm.envAddress("eth_mainnet"));
        link = ERC20(vm.envAddress("link_mainnet"));
        snx = ERC20(vm.envAddress("snx_mainnet"));
        usdc = ERC20(vm.envAddress("usdc_mainnet"));
        btc = ERC20(vm.envAddress("btc_mainnet"));

        oracleDaiToUsdArr[0] = vm.envAddress("oracleDaiToUsd_mainnet");
        oracleEthToUsdArr[0] = vm.envAddress("oracleEthToUsd_mainnet");
        oracleLinkToEthEthToUsdArr[0] = vm.envAddress("oracleLinkToEth_mainnet");
        oracleLinkToEthEthToUsdArr[1] = vm.envAddress("oracleEthToUsd_mainnet");
        oracleSnxToUsdArr[0] = vm.envAddress("oracleSnxToUsd_mainnet");
        oracleUsdcToUsdArr[0] = vm.envAddress("oracleUsdcToUsd_mainnet");
        oracleBtcToEthEthToUsdArr[0] = vm.envAddress("oracleBtcToEth_mainnet");
        oracleBtcToEthEthToUsdArr[1] = vm.envAddress("oracleEthToUsd_mainnet");

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: vm.envAddress("oracleDaiToUsd_mainnet"),
            baseAssetAddress: vm.envAddress("dai_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "wETH",
            quoteAsset: "USD",
            oracle: vm.envAddress("oracleEthToUsd_mainnet"),
            baseAssetAddress: vm.envAddress("eth_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        linkToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleLinkToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "LINK",
            quoteAsset: "wETH",
            oracle: vm.envAddress("oracleLinkToEth_mainnet"),
            baseAssetAddress: vm.envAddress("link_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        snxToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleSnxToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "SNX",
            quoteAsset: "USD",
            oracle: vm.envAddress("oracleSnxToUsd_mainnet"),
            baseAssetAddress: vm.envAddress("snx_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: vm.envAddress("oracleUsdcToUsd_mainnet"),
            baseAssetAddress: vm.envAddress("usdc_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        btcToEthEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleBtcToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "BTC",
            quoteAsset: "wETH",
            oracle: vm.envAddress("oracleBtcToEth_mainnet"),
            baseAssetAddress: vm.envAddress("btc_mainnet"),
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: vm.envAddress("eth_mainnet"),
            baseCurrencyToUsdOracle: address(vm.envAddress("oracleEthToUsd_mainnet")),
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.ethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: vm.envAddress("usdc_mainnet"),
            baseCurrencyToUsdOracle: address(vm.envAddress("oracleUsdcToUsd_mainnet")),
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.dai_collFact_0,
                liquidationFactor: DeployRiskConstants.dai_liqFact_0
            })
        );
        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.dai_collFact_1,
                liquidationFactor: DeployRiskConstants.dai_liqFact_1
            })
        );
        riskVarsDai.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.dai_collFact_2,
                liquidationFactor: DeployRiskConstants.dai_liqFact_2
            })
        );

        riskVarsEth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.eth_collFact_0,
                liquidationFactor: DeployRiskConstants.eth_liqFact_0
            })
        );
        riskVarsEth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.eth_collFact_1,
                liquidationFactor: DeployRiskConstants.eth_liqFact_1
            })
        );
        riskVarsEth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.eth_collFact_2,
                liquidationFactor: DeployRiskConstants.eth_liqFact_2
            })
        );

        riskVarsLink.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.link_collFact_0,
                liquidationFactor: DeployRiskConstants.link_liqFact_0
            })
        );
        riskVarsLink.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.link_collFact_1,
                liquidationFactor: DeployRiskConstants.link_liqFact_1
            })
        );
        riskVarsLink.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.link_collFact_2,
                liquidationFactor: DeployRiskConstants.link_liqFact_2
            })
        );

        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.snx_collFact_0,
                liquidationFactor: DeployRiskConstants.snx_liqFact_0
            })
        );
        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.snx_collFact_1,
                liquidationFactor: DeployRiskConstants.snx_liqFact_1
            })
        );
        riskVarsSnx.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.snx_collFact_2,
                liquidationFactor: DeployRiskConstants.snx_liqFact_2
            })
        );

        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.usdc_collFact_0,
                liquidationFactor: DeployRiskConstants.usdc_liqFact_0
            })
        );
        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.usdc_collFact_1,
                liquidationFactor: DeployRiskConstants.usdc_liqFact_1
            })
        );
        riskVarsUsdc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.usdc_collFact_2,
                liquidationFactor: DeployRiskConstants.usdc_liqFact_2
            })
        );

        riskVarsBtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstants.btc_collFact_0,
                liquidationFactor: DeployRiskConstants.btc_liqFact_0
            })
        );
        riskVarsBtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstants.btc_collFact_1,
                liquidationFactor: DeployRiskConstants.btc_liqFact_1
            })
        );
        riskVarsBtc.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstants.btc_collFact_2,
                liquidationFactor: DeployRiskConstants.btc_liqFact_2
            })
        );
    }

    function run() public {
        uint256 anvilPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY_USER");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");

        vm.startBroadcast(anvilPrivateKey);
        payable(address(weth)).call{ value: 5000 ether }("");
        payable(vm.addr(userPrivateKey)).transfer(1000 ether);
        payable(vm.addr(deployerPrivateKey)).transfer(1000 ether);
        weth.transfer(vm.addr(userPrivateKey), 5000 ether);
        vm.stopBroadcast();

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

        PricingModule.RiskVarInput[] memory riskVarsDai_ = riskVarsDai;
        PricingModule.RiskVarInput[] memory riskVarsEth_ = riskVarsEth;
        PricingModule.RiskVarInput[] memory riskVarsLink_ = riskVarsLink;
        PricingModule.RiskVarInput[] memory riskVarsSnx_ = riskVarsSnx;
        PricingModule.RiskVarInput[] memory riskVarsUsdc_ = riskVarsUsdc;
        PricingModule.RiskVarInput[] memory riskVarsBtc_ = riskVarsBtc;

        standardERC20PricingModule.addAsset(
            vm.envAddress("dai_mainnet"), oracleDaiToUsdArr, riskVarsDai_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            vm.envAddress("eth_mainnet"), oracleEthToUsdArr, riskVarsEth_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            vm.envAddress("link_mainnet"), oracleLinkToEthEthToUsdArr, riskVarsLink_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            vm.envAddress("snx_mainnet"), oracleSnxToUsdArr, riskVarsSnx_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            vm.envAddress("usdc_mainnet"), oracleUsdcToUsdArr, riskVarsUsdc_, type(uint128).max
        );
        standardERC20PricingModule.addAsset(
            vm.envAddress("btc_mainnet"), oracleBtcToEthEthToUsdArr, riskVarsBtc_, type(uint128).max
        );

        vault = new Vault(address(mainRegistry), 1);
        factory.setNewVaultInfo(address(mainRegistry), address(vault), DeployBytes.upgradeRoot1To1, "");

        actionMultiCall = new ActionMultiCall(address(mainRegistry));
        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        ERC20[] memory assets = new ERC20[](2);
        assets[0] = usdc;
        assets[1] = weth;

        pool_weth =
        new LendingPool(ERC20(address(weth)), 0x12e463251Bc79677FD980aA6c301d5Fb85101cCb, address(factory), address(0));
        srTranche_weth = new Tranche(address(pool_weth), "Senior", "SR");
        jrTranche_weth = new Tranche(address(pool_weth), "Junior", "JR");

        pool_weth.setVaultVersion(1, true);
        pool_weth.setOriginationFee(10);
        pool_weth.addTranche(address(srTranche_weth), 50, 0);
        pool_weth.addTranche(address(jrTranche_weth), 40, 20);
        pool_weth.setTreasuryInterestWeight(10);
        pool_weth.setTreasuryLiquidationWeight(80);
        pool_weth.setSupplyCap(5000 * 10 ** 18);
        pool_weth.setInterestConfig(
            DataTypes.InterestRateConfiguration({
                baseRatePerYear: 30_000_000_000_000_000,
                lowSlopePerYear: 85_000_000_000_000_000,
                highSlopePerYear: 1_250_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        pool_usdc =
        new LendingPool(ERC20(address(usdc)), 0x12e463251Bc79677FD980aA6c301d5Fb85101cCb, address(factory), address(0));
        srTranche_usdc = new Tranche(address(pool_usdc), "Senior", "SR");
        jrTranche_usdc = new Tranche(address(pool_usdc), "Junior", "JR");

        pool_usdc.setVaultVersion(1, true);
        pool_usdc.setOriginationFee(10);
        pool_usdc.addTranche(address(srTranche_usdc), 50, 0);
        pool_usdc.addTranche(address(jrTranche_usdc), 40, 20);
        pool_usdc.setTreasuryInterestWeight(10);
        pool_usdc.setTreasuryLiquidationWeight(80);
        pool_usdc.setSupplyCap(500_000 * 10 ** 6);
        pool_usdc.setInterestConfig(
            DataTypes.InterestRateConfiguration({
                baseRatePerYear: 25_000_000_000_000_000,
                lowSlopePerYear: 70_000_000_000_000_000,
                highSlopePerYear: 1_000_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        vm.stopBroadcast();
    }
}
