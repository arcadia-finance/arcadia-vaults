/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { MainRegistry } from "../src/MainRegistry.sol";
import { ActionMultiCallV2 } from "../src/Actions/ActionMultiCallV2.sol";

contract MultiCallV2Deployer is Test {
    MainRegistry public mainRegistry = MainRegistry(0x046fc9f35EB7Cb165a5e07915d37bF4022b8dE33);
    ActionMultiCallV2 public action;

    constructor() { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_OPTIMISM");

        vm.startBroadcast(deployerPrivateKey);
        action = new ActionMultiCallV2();
        mainRegistry.setAllowedAction(address(action), true);

        vm.stopBroadcast();
    }
}
