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

import { DataTypes } from "../lib/arcadia-lending/src/libraries/DataTypes.sol";
import { ERC20, DebtToken } from "../lib/arcadia-lending/src/DebtToken.sol";
import { LendingPool } from "../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../lib/arcadia-lending/src/Tranche.sol";
import { TrustedCreditor } from "../lib/arcadia-lending/src/TrustedCreditor.sol";

contract ArcadiaLendingDeployerMainnet is Test {
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
        weth = ERC20(DeployAddresses.eth_mainnet);
        usdc = ERC20(DeployAddresses.usdc_mainnet);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");

        vm.startBroadcast(deployerPrivateKey);

        factory = new Factory();
        liquidator = new Liquidator(address(factory));

        pool_weth =
            new LendingPool(ERC20(address(weth)), DeployAddresses.treasury_mainnet, address(factory), address(liquidator));
        srTranche_weth = new Tranche(address(pool_weth), "Senior", "sr");
        jrTranche_weth = new Tranche(address(pool_weth), "Junior", "jr");

        pool_weth.setOriginationFee(10);
        pool_weth.setMaxInitiatorFee(33 * 10 ** 18);
        pool_weth.setFixedLiquidationCost(0.075*10**18);
        pool_weth.addTranche(address(srTranche_weth), 50, 0);
        pool_weth.addTranche(address(jrTranche_weth), 40, 50);
        pool_weth.setTreasuryInterestWeight(10);
        pool_weth.setTreasuryLiquidationWeight(50);
        pool_weth.setSupplyCap(1);
        pool_weth.setBorrowCap(1);
        pool_weth.setInterestConfig(
            DataTypes.InterestRateConfiguration({
                baseRatePerYear: 15_000_000_000_000_000,
                lowSlopePerYear: 70_000_000_000_000_000,
                highSlopePerYear: 1_250_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        pool_usdc =
            new LendingPool(ERC20(address(usdc)), DeployAddresses.treasury, address(factory), address(liquidator));
        srTranche_usdc = new Tranche(address(pool_usdc), "Senior", "sr");
        jrTranche_usdc = new Tranche(address(pool_usdc), "Junior", "jr");

        pool_usdc.setOriginationFee(10);
        pool_usdc.setMaxInitiatorFee(50_000 * 10 ** 6);
        pool_usdc.setFixedLiquidationCost(100*10**6);
        pool_usdc.addTranche(address(srTranche_usdc), 50, 0);
        pool_usdc.addTranche(address(jrTranche_usdc), 40, 50);
        pool_usdc.setTreasuryInterestWeight(10);
        pool_usdc.setTreasuryLiquidationWeight(50);
        pool_usdc.setSupplyCap(1);
        pool_usdc.setBorrowCap(1);
        pool_usdc.setInterestConfig(
            DataTypes.InterestRateConfiguration({
                baseRatePerYear: 10_000_000_000_000_000,
                lowSlopePerYear: 55_000_000_000_000_000,
                highSlopePerYear: 1_000_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );

        vm.stopBroadcast();
    }
}
