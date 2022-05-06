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

 function setVaultInfo(uint256 version, address registryAddress, address logic, address stable, address stakeContract, address interestModule) external override onlyOwner {
   
 }

  function setVaultInfo(uint256 version, address registryAddress, address logic, address stable, address stakeContract, address interestModule, address _tokenShop) external onlyOwner {
    vaultDetails[version].registryAddress = registryAddress;
    vaultDetails[version].logic = logic;
    vaultDetails[version].stable = stable;
    vaultDetails[version].stakeContract = stakeContract;
    vaultDetails[version].interestModule = interestModule;
    tokenShop = _tokenShop;
  }

  /** 
  @notice Function used to create a Vault
  @dev This is the starting point of the Vault creation process. 
  @param salt A salt to be used to generate the hash.
*/
  function createVault(uint256 salt) external override returns (address vault) {
    bytes memory initCode = type(Proxy).creationCode;
    bytes memory byteCode = abi.encodePacked(initCode, abi.encode(vaultDetails[currentVaultVersion].logic));

    assembly {
        vault := create2(0, add(byteCode, 32), mload(byteCode), salt)
    }
    IVaultPaperTrading(vault).initialize(msg.sender, 
                              vaultDetails[currentVaultVersion].registryAddress, 
                              vaultDetails[currentVaultVersion].stable, 
                              vaultDetails[currentVaultVersion].stakeContract, 
                              vaultDetails[currentVaultVersion].interestModule,
                              tokenShop);
    
    
    allVaults.push(vault);
    isVault[vault] = true;

    _mint(msg.sender, allVaults.length -1);
    emit VaultCreated(vault, msg.sender, allVaults.length);
  }

}