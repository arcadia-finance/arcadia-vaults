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
import "../../../utils/StringHelpers.sol";

interface IVaultValue {
  function getValue(uint8) external view returns (uint256);
}

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

    deployCoordinator.start();
    
    deployContractsAssets.setAddr(address(deployCoordinator.oracleEthToUsd()), address(deployCoordinator.weth()));

    deployContractsAssets.storeAssets();
    deployContractsAssets.transferAssets(address(deployCoordinator));

    deployCoordinator.deployERC20Contracts();
    deployCoordinator.deployERC721Contracts();
    deployCoordinator.deployOracles();
    deployCoordinator.setOracleAnswers();
    deployCoordinator.addOracles();
    emit log_named_address("OracleEThToUsd", address(deployCoordinator.oracleEthToUsd()));
    checkOracle();
    deployCoordinator.setAssetInformation();

    deployCoordinator.verifyView();

    deployCoordinator.createNewVaultThroughDeployer(address(this));


    vm.startPrank(address(3));
    address firstVault = IFactoryPaperTradingExtended(deployCoordinator.factory()).createVault(125498456465, 0);
    address secondVault = IFactoryPaperTradingExtended(deployCoordinator.factory()).createVault(125498456465545885545, 1);
    vm.stopPrank();

    emit log_named_uint("vault1value", IVaultValue(firstVault).getValue(0));
    emit log_named_uint("vault1value", IVaultValue(secondVault).getValue(1));
  }

  function checkOracle() public {
    uint256 len = deployContractsAssets.assetLength();
    address oracleAddr_t;
    string memory symb;
    for (uint i; i < len; ++i) {
      (,symb,,,,,, oracleAddr_t,) = deployCoordinator.assets(i);
      if (StringHelpers.compareStrings(symb, "mwETH")) {
        emit log_named_address("Orac from assets", oracleAddr_t);
      }
    }
  }


  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

}