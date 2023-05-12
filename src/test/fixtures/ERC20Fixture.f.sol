/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";

contract ERC20Fixture is Test {
    function createToken(address deployer, uint8 decimals) public returns (ERC20Mock token) {
        vm.prank(deployer);
        token = new ERC20Mock('Token', 'TOK', decimals);
    }

    function createToken() public returns (ERC20Mock token) {
        token = createToken(0xbA32A3D407353FC3adAA6f7eC6264Df5bCA51c4b, 18);
    }
}
