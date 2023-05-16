/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses } from "./Constants/DeployConstants.sol";

import { MainRegistry } from "../src/MainRegistry.sol";
import { StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import {
    PricingModule,
    UniswapV3WithFeesPricingModule
} from "../src/PricingModules/UniswapV3/UniswapV3WithFeesPricingModule.sol";
import { OracleHub } from "../src/OracleHub.sol";

import { UniV3Helper } from "../src/utils/UniV3Helper.sol";

contract ArcadiaUniV3DeployerMainnet is Test {
    MainRegistry public constant mainRegistry = MainRegistry(0x046fc9f35EB7Cb165a5e07915d37bF4022b8dE33);
    OracleHub public constant oracleHub = OracleHub(0x950A8833b9533A19Fb4D1B2EFC823Ea6835f6d95);
    StandardERC20PricingModule public constant standardERC20PricingModule =
        StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);

    address public constant deployer = 0xbA32A3D407353FC3adAA6f7eC6264Df5bCA51c4b;

    UniswapV3WithFeesPricingModule public uniV3PricingModule;
    UniV3Helper public uniV3Helper;

    constructor() { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_MAINNET");

        vm.startBroadcast(deployerPrivateKey);

        uniV3PricingModule = new UniswapV3WithFeesPricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(deployer),
            address(standardERC20PricingModule)
        );

        uniV3Helper = new UniV3Helper(address(uniV3PricingModule));

        mainRegistry.addPricingModule(address(uniV3PricingModule));

        uniV3PricingModule.setExposureOfAsset(DeployAddresses.crv_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.dai_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.frax_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.fxs_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.link_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.snx_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.uni_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.usdc_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.usdt_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.wbtc_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.weth_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.cbeth_mainnet, type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(DeployAddresses.reth_mainnet, type(uint128).max);

        vm.stopBroadcast();
    }
}
