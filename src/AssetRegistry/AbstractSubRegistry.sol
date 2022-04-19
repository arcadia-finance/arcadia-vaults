// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../interfaces/IOraclesHub.sol";
import "../interfaces/IMainRegistry.sol";
import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Abstract Sub-registry
  * @author Arcadia Finance
  * @notice Sub-Registries store pricing logic and basic information for tokens that can, or could at some point, be deposited in the vaults
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */ 
abstract contract SubRegistry is Ownable {
  using FixedPointMathLib for uint256;
  
  address public _mainRegistry;
  address public _oracleHub;
  address[] public assetsInSubRegistry;
  mapping (address => bool) public inSubRegistry;
  mapping (address => bool) public isAssetAddressWhiteListed;

  struct GetValueInput {
    address assetAddress;
    uint256 assetId;
    uint256 assetAmount;
    uint256 numeraire;
  }

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor (address mainRegistry, address oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //ToDo Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address, uint256) external view virtual returns (bool) {
    return false;
  }

  /**
   * @notice Removes an asset from the white-list
   * @param assetAddress The token address of the asset that needs to be removed from the white-list
   */
  function removeFromWhiteList(address assetAddress) external onlyOwner {
    require(inSubRegistry[assetAddress], 'Asset not known in Sub-Registry');
    isAssetAddressWhiteListed[assetAddress] = false;
  }

  /**
   * @notice Adds an asset to the white-list
   * @param assetAddress The token address of the asset that needs to be added to the white-list
   */
  function addToWhiteList(address assetAddress) external onlyOwner {
    require(inSubRegistry[assetAddress], 'Asset not known in Sub-Registry');
    isAssetAddressWhiteListed[assetAddress] = true;
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   */
  function getValue(GetValueInput memory) public view virtual returns (uint256, uint256) {
    
  }

}

