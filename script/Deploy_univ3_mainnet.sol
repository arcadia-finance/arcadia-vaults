/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers } from "./Constants/DeployConstants.sol";

import { MainRegistry } from "../src/MainRegistry.sol";
import { StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import { PricingModule, UniswapV3PricingModule } from "../src/PricingModules/UniswapV3/UniswapV3PricingModule.sol";
import { OracleHub } from "../src/OracleHub.sol";

contract ArcadiaUniV3DeployerMainnet is Test {
    MainRegistry public constant mainRegistry = MainRegistry(0x046fc9f35EB7Cb165a5e07915d37bF4022b8dE33);
    OracleHub public constant oracleHub = OracleHub(0x950A8833b9533A19Fb4D1B2EFC823Ea6835f6d95);
    StandardERC20PricingModule public constant standardERC20PricingModule =
        StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);

    address public constant deployer = 0xbA32A3D407353FC3adAA6f7eC6264Df5bCA51c4b;

    UniswapV3PricingModule public uniV3PricingModule;

    constructor() { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_MAINNET");

        vm.startBroadcast(deployerPrivateKey);

        uniV3PricingModule = new UniswapV3PricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(deployer),
            address(standardERC20PricingModule)
        );

        mainRegistry.addPricingModule(address(uniV3PricingModule));
        uniV3PricingModule.addAsset(DeployAddresses.uniswapV3PositionMgr_mainnet);

        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.crv_mainnet, uint128(6_000_000 * 10 ** DeployNumbers.crvDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.dai_mainnet, uint128(75_000_000 * 10 ** DeployNumbers.daiDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.frax_mainnet, uint128(35_000_000 * 10 ** DeployNumbers.fraxDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.fxs_mainnet, uint128(300_000 * 10 ** DeployNumbers.fxsDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.link_mainnet, uint128(6_500_000 * 10 ** DeployNumbers.linkDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.snx_mainnet, uint128(300_000 * 10 ** DeployNumbers.snxDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.uni_mainnet, uint128(600_000 * 10 ** DeployNumbers.uniDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.usdc_mainnet, uint128(75_000_000 * 10 ** DeployNumbers.usdcDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.usdt_mainnet, uint128(70_000_000 * 10 ** DeployNumbers.usdtDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.wbtc_mainnet, uint128(3500 * 10 ** DeployNumbers.wbtcDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.weth_mainnet, uint128(50_000 * 10 ** DeployNumbers.wethDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.cbeth_mainnet, uint128(2250 * 10 ** DeployNumbers.cbethDecimals)
        );
        uniV3PricingModule.setExposureOfAsset(
            DeployAddresses.reth_mainnet, uint128(35_000 * 10 ** DeployNumbers.rethDecimals)
        );

        vm.stopBroadcast();
    }
}
