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
    deployer.storeStructs();
  }

  // function setUp() public {
  //   deployer = new DeployContracts();
  //   deployer.storeStructs();
  // }

  function test() public {
    assertTrue(address(deployer) != address(0));
  }

  function testDeployERC20Assets() public {
    deployer.deployERC20Contracts();
  }

  function testDeployERC721Assets() public {
    deployer.deployERC721Contracts();
  }

  function testDeployOracles() public {
    deployer.deployOracles();
    deployer.setOracleAnswers();
    deployer.addOracles();
    deployer.setAssetInformation();
  }

  function testVerify() public {
    assertTrue(deployer.verify());
  }

  // function testsetOracleAnswers() public {
  //   deployer.setOracleAnswers();
  // }

  // function testaddOracles() public {
  //   deployer.addOracles();
  // }

  // function testsetAssetInformation() public {
  //   deployer.setAssetInformation();
  // }

}