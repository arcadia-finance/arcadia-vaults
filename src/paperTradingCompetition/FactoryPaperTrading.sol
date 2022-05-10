// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../Factory.sol";
import "./interfaces/IVaultPaperTrading.sol";

contract FactoryPaperTrading is Factory {
  address tokenShop;

  function getVaultAddress(uint256 id) external view returns(address) {
      return allVaults[id];
  }

 function setNewVaultInfo(address, address, address, address) external view override onlyOwner {
   revert('Not Allowed');
 }

  function setNewVaultInfo(address registryAddress, address logic, address stakeContract, address interestModule, address _tokenShop) external onlyOwner {
    vaultDetails[currentVaultVersion+1].registryAddress = registryAddress;
    vaultDetails[currentVaultVersion+1].logic = logic;
    vaultDetails[currentVaultVersion+1].stakeContract = stakeContract;
    vaultDetails[currentVaultVersion+1].interestModule = interestModule;
    tokenShop = _tokenShop;

    //If there is a new Main Registry Contract, Check that numeraires in factory and main registry match
    if (factoryInitialised && vaultDetails[currentVaultVersion].registryAddress != registryAddress) {
      address mainRegistryStableAddress;
      for (uint256 i; i < numeraireCounter;) {
        (,,,,mainRegistryStableAddress,) = IMainRegistry(registryAddress).numeraireToInformation(i);
        require(mainRegistryStableAddress == numeraireToStable[i], "FTRY_SNVI:No match numeraires MR");
        unchecked {++i;}
      }
    }
  }

  /** 
  @notice Function used to create a Vault
  @dev This is the starting point of the Vault creation process. 
  @param salt A salt to be used to generate the hash.
  @param numeraire An identifier (uint256) of the Numeraire
*/
  function createVault(uint256 salt, uint256 numeraire) external override returns (address vault) {
    bytes memory initCode = type(Proxy).creationCode;
    bytes memory byteCode = abi.encodePacked(initCode, abi.encode(vaultDetails[currentVaultVersion].logic));

    assembly {
        vault := create2(0, add(byteCode, 32), mload(byteCode), salt)
    }

    allVaults.push(vault);
    isVault[vault] = true;

    IVaultPaperTrading(vault).initialize(msg.sender, 
                              vaultDetails[currentVaultVersion].registryAddress, 
                              numeraireToStable[numeraire], 
                              vaultDetails[currentVaultVersion].stakeContract, 
                              vaultDetails[currentVaultVersion].interestModule,
                              tokenShop);


    _mint(msg.sender, allVaults.length -1);
    emit VaultCreated(vault, msg.sender, allVaults.length);
  }

}