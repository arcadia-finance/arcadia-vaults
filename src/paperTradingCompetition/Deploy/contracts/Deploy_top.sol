// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "./Deploy_coordinator.sol";
import "./Deploy_one.sol";
import "./Deploy_two.sol";
import "./Deploy_three.sol";
import "./Deploy_four.sol";
import "./Deploy_assets.sol";

import "../../../../lib/ds-test/src/test.sol";
import "../../../../lib/forge-std/src/stdlib.sol";
import "../../../../lib/forge-std/src/console.sol";
import "../../../../lib/forge-std/src/Vm.sol";

contract DeployCoordTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  DeployCoordinator public deployCoordinator;
  DeployContractsOne public deployContractsOne;
  DeployContractsTwo public deployContractsTwo;
  DeployContractsThree public deployContractsThree;
  DeployContractsFour public deployContractsFour;
  DeployContractsAssets public deployContractsAssets;


  constructor() {}

  
  function testDeployAll() public {
    deployContractsOne = new DeployContractsOne();
    deployContractsTwo = new DeployContractsTwo();
    deployContractsThree = new DeployContractsThree();
    deployContractsFour = new DeployContractsFour();
    deployContractsAssets = new DeployContractsAssets();

    deployCoordinator = new DeployCoordinator(address(deployContractsOne),address(deployContractsTwo),address(deployContractsThree),address(deployContractsFour),address(deployContractsAssets));

    deployContractsAssets.storeAssets();
    deployContractsAssets.transferAssets(address(deployCoordinator));

    deployCoordinator.start();

    deployCoordinator.deployERC20Contracts();
    deployCoordinator.deployERC721Contracts();
    deployCoordinator.deployOracles();
    deployCoordinator.setOracleAnswers();
    deployCoordinator.addOracles();
    deployCoordinator.setAssetInformation();

    deployCoordinator.verifyView();
  }

}