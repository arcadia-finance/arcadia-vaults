/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {
    DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsMainnet
} from "./Constants/DeployConstants.sol";

import { StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";

import { ERC20 } from "../lib/arcadia-lending/src/DebtToken.sol";
import { LendingPool } from "../lib/arcadia-lending/src/LendingPool.sol";

contract ExposureSetterOptimism is Test {
    ERC20 public dai;
    ERC20 public frax;
    ERC20 public snx;
    ERC20 public usdc;
    ERC20 public usdt;
    ERC20 public wbtc;
    ERC20 public weth;
    ERC20 public wsteth;
    ERC20 public op;

    StandardERC20PricingModule public standardERC20PricingModule =
        StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);
    LendingPool public wethLendingPool = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);
    LendingPool public usdcLendingPool = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_OPTIMISM");

        vm.startBroadcast(deployerPrivateKey);

        standardERC20PricingModule.setExposureOfAsset(
            address(dai), uint128(10_000_000 * 10 ** DeployNumbers.daiDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(
            address(frax), uint128(400_000 * 10 ** DeployNumbers.fraxDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(snx), uint128(500_000 * 10 ** DeployNumbers.snxDecimals));
        standardERC20PricingModule.setExposureOfAsset(
            address(usdc), uint128(15_000_000 * 10 ** DeployNumbers.usdcDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(
            address(usdt), uint128(10_000_000 * 10 ** DeployNumbers.usdtDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(wbtc), uint128(70 * 10 ** DeployNumbers.wbtcDecimals));
        standardERC20PricingModule.setExposureOfAsset(address(weth), uint128(15_000 * 10 ** DeployNumbers.wethDecimals));
        standardERC20PricingModule.setExposureOfAsset(
            address(wsteth), uint128(3000 * 10 ** DeployNumbers.wstethDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(op), uint128(150_000 * 10 ** DeployNumbers.opDecimals));

        wethLendingPool.setBorrowCap(uint128(250 * 10 ** DeployNumbers.wethDecimals));
        usdcLendingPool.setBorrowCap(uint128(500_000 * 10 ** DeployNumbers.usdcDecimals));

        vm.stopBroadcast();
    }
}
