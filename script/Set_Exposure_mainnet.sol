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
import { LendingPool, InterestRateModule } from "../lib/arcadia-lending/src/LendingPool.sol";

contract ExposureSetterMainnet is Test {
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

    StandardERC20PricingModule public standardERC20PricingModule =
        StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);
    LendingPool public wethLendingPool = LendingPool(0xD417c28aF20884088F600e724441a3baB38b22cc);
    LendingPool public usdcLendingPool = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_MAINNET");

        vm.startBroadcast(deployerPrivateKey);
        standardERC20PricingModule.setExposureOfAsset(
            address(crv), uint128(6_000_000 * 10 ** DeployNumbers.crvDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(
            address(dai), uint128(75_000_000 * 10 ** DeployNumbers.daiDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(
            address(frax), uint128(35_000_000 * 10 ** DeployNumbers.fraxDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(fxs), uint128(300_000 * 10 ** DeployNumbers.fxsDecimals));
        standardERC20PricingModule.setExposureOfAsset(
            address(link), uint128(6_500_000 * 10 ** DeployNumbers.linkDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(snx), uint128(300_000 * 10 ** DeployNumbers.snxDecimals));
        standardERC20PricingModule.setExposureOfAsset(address(uni), uint128(600_000 * 10 ** DeployNumbers.uniDecimals));
        standardERC20PricingModule.setExposureOfAsset(
            address(usdc), uint128(75_000_000 * 10 ** DeployNumbers.usdcDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(
            address(usdt), uint128(70_000_000 * 10 ** DeployNumbers.usdtDecimals)
        );
        standardERC20PricingModule.setExposureOfAsset(address(wbtc), uint128(3500 * 10 ** DeployNumbers.wbtcDecimals));
        standardERC20PricingModule.setExposureOfAsset(address(weth), uint128(50_000 * 10 ** DeployNumbers.wethDecimals));
        standardERC20PricingModule.setExposureOfAsset(address(cbeth), uint128(2250 * 10 ** DeployNumbers.cbethDecimals));

        wethLendingPool.setBorrowCap(uint128(500 * 10 ** DeployNumbers.wethDecimals));
        usdcLendingPool.setBorrowCap(uint128(1_000_000 * 10 ** DeployNumbers.usdcDecimals));

        wethLendingPool.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 45_000_000_000_000_000,
                lowSlopePerYear: 131_250_000_000_000_000,
                highSlopePerYear: 1_250_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );
        usdcLendingPool.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 30_000_000_000_000_000,
                lowSlopePerYear: 112_500_000_000_000_000,
                highSlopePerYear: 1_000_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        vm.stopBroadcast();
    }
}
