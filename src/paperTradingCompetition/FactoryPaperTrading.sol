// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../Factory.sol";
import "./interfaces/IVaultPaperTrading.sol";

contract FactoryPaperTrading is Factory {
  address tokenShop;

  /** 
    @notice returns contract address of individual vaults
    @param id The id of the Vault
    @return vaultAddress The contract address of the individual vault
  */
  function getVaultAddress(uint256 id) external view returns(address vaultAddress) {
    vaultAddress = allVaults[id];
  }

  /** 
    @notice Function to set a new contract for the tokenshop logic
    @param _tokenShop The new tokenshop contract
  */
  function setTokenShop(address _tokenShop) public onlyOwner {
    tokenShop = _tokenShop;
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
    vaultIndex[vault] = allVaults.length - 1;

    IVaultPaperTrading(vault).initialize(msg.sender, 
                              vaultDetails[currentVaultVersion].registryAddress, 
                              numeraireToStable[numeraire], 
                              vaultDetails[currentVaultVersion].stakeContract, 
                              vaultDetails[currentVaultVersion].interestModule,
                              tokenShop);


    _mint(msg.sender, allVaults.length -1);
    emit VaultCreated(vault, msg.sender, allVaults.length -1);
  }

  function liquidate(address) external pure override {
    revert('Not Allowed');
  }

  function liquidate(address vaultLiquidate, address vaultReward) external {
    _liquidate(vaultLiquidate, msg.sender);
    IVaultPaperTrading(vaultReward).receiveReward();
  }

}