/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/MainRegistry.sol";
import "../src/actions/MultiCall.sol";

contract ArcadiaMultiCallDeployer is Test {
    MainRegistry public mainRegistry;
    ActionMultiCall public actionMultiCall;

    constructor() { }

    function deployMultiCall() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        mainRegistry = MainRegistry(0x6403fCb38C5879422ECc77933d4bC8fDcECe79Ec);
        actionMultiCall = new ActionMultiCall(address(mainRegistry));
        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        vm.stopBroadcast();
    }
}
