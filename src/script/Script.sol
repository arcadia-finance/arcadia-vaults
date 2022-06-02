//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Contract.sol";
import "../../lib/forge-std/src/Script.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast();

        Contract c = new Contract();
        c.test();
        require(c.x() == 12345 && 1 == 1);
    }
}