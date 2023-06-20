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

contract ArcadiaVaultDeployerBase is Test {
    Factory public factory;
    Vault public vault;

    ERC20 public usdc;
    ERC20 public weth;

    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    Liquidator public liquidator;
    ActionMultiCall public actionMultiCall;

    LendingPool public wethLendingPool = LendingPool(0x85849F31F921Cf0FB36cD79CD85d74e066C0455A);
    LendingPool public usdcLendingPool = LendingPool(0xb30E45681fA9F397B956A7197655A57feac4eA32);

    constructor() { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST_DEPLOYER");

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0xA04B08324745AEc82De30c3581c407BE63E764c8);
        liquidator = Liquidator(0x28bE1B63E01eDD073D45D3aB522a905BD45ff492);

        mainRegistry = new MainRegistry(address(factory));
        oracleHub = new OracleHub();
        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub),
            0
        );

        vault = new Vault();
        actionMultiCall = new ActionMultiCall();

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
