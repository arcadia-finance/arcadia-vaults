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
import { Liquidator } from "../src/Liquidator.sol";

import { ERC20, DebtToken } from "../lib/arcadia-lending/src/DebtToken.sol";
import { LendingPool, InterestRateModule } from "../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../lib/arcadia-lending/src/Tranche.sol";
import { TrustedCreditor } from "../lib/arcadia-lending/src/TrustedCreditor.sol";

contract ArcadiaLendingDeployerOptimism is Test {
    Factory public factory;
    ERC20 public weth;
    ERC20 public usdc;
    Liquidator public liquidator;

    LendingPool public pool_weth;
    Tranche public srTranche_weth;
    Tranche public jrTranche_weth;

    LendingPool public pool_usdc;
    Tranche public srTranche_usdc;
    Tranche public jrTranche_usdc;

    constructor() {
        weth = ERC20(DeployAddresses.eth_optimism);
        usdc = ERC20(DeployAddresses.usdc_optimism);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_OPTIMISM");

        vm.startBroadcast(deployerPrivateKey);

        factory = new Factory();
        liquidator = new Liquidator(address(factory));

        pool_weth =
        new LendingPool(ERC20(address(weth)), DeployAddresses.treasury_optimism, address(factory), address(liquidator));
        srTranche_weth = new Tranche(address(pool_weth), "Senior", "sr");
        jrTranche_weth = new Tranche(address(pool_weth), "Junior", "jr");

        pool_weth.setOriginationFee(10);
        pool_weth.setMaxInitiatorFee(3 * 10 ** 18);
        pool_weth.setFixedLiquidationCost(0.002 * 10 ** 18);
        pool_weth.addTranche(address(srTranche_weth), 50, 0);
        pool_weth.addTranche(address(jrTranche_weth), 40, 50);
        pool_weth.setTreasuryInterestWeight(10);
        pool_weth.setTreasuryLiquidationWeight(50);
        pool_weth.setSupplyCap(1);
        pool_weth.setBorrowCap(1);
        pool_weth.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 15_000_000_000_000_000,
                lowSlopePerYear: 70_000_000_000_000_000,
                highSlopePerYear: 1_250_000_000_000_000_000,
                utilisationThreshold: 70_000
            })
        );

        pool_usdc =
        new LendingPool(ERC20(address(usdc)), DeployAddresses.treasury_optimism, address(factory), address(liquidator));
        srTranche_usdc = new Tranche(address(pool_usdc), "Senior", "sr");
        jrTranche_usdc = new Tranche(address(pool_usdc), "Junior", "jr");

        pool_usdc.setOriginationFee(10);
        pool_usdc.setMaxInitiatorFee(5000 * 10 ** 6);
        pool_usdc.setFixedLiquidationCost(2 * 10 ** 6);
        pool_usdc.addTranche(address(srTranche_usdc), 50, 0);
        pool_usdc.addTranche(address(jrTranche_usdc), 40, 20);
        pool_usdc.setTreasuryInterestWeight(10);
        pool_usdc.setTreasuryLiquidationWeight(50);
        pool_usdc.setSupplyCap(1);
        pool_usdc.setBorrowCap(1);
        pool_usdc.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 10_000_000_000_000_000,
                lowSlopePerYear: 55_000_000_000_000_000,
                highSlopePerYear: 1_000_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        vm.stopBroadcast();
    }
}
