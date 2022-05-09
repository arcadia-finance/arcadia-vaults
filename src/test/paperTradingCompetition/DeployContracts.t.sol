// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/stdlib.sol";
import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Vm.sol";

import "./DeployContracts.sol";

contract DeployPaperTests is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  DeployContracts public deployer;

  constructor() {
    deployer = new DeployContracts();
  }

  function test() public {
    assertTrue(address(deployer) != address(0));
  }

  function testDeployAssets() public {
    deployer.storeStructs();
    deployer.deployAssetContracts();
  }

}