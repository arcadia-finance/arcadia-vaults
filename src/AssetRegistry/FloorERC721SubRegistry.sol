// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";

/** 
  * @title Sub-registry for ERC721 tokens for which a oracle exists for the floor price of the collection
  * @author Arcadia Finance
  * @notice The FloorERC721SubRegistry stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
  *         for the floor price of the collection
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721SubRegistry is SubRegistry {

  struct AssetInformation {
    uint256 idRangeStart;
    uint256 idRangeEnd;
    address assetAddress;
    address[] oracleAddresses;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor(address mainRegistry, address oracleHub) SubRegistry(mainRegistry, oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }
  
  /**
   * @notice Add a new asset to the FloorERC721SubRegistry, or overwrite an existing one
   * @param assetInformation A Struct with information about the asset 
   * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires
   * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
   *      or the list must have lenth 0. If the list has length zero, the credit ratings of the asset for all numeraires is
   *      is initiated as credit rating with index 0 by default (worst credit rating)
   * @dev The asset needs to be added/overwritten in the Main-Registry as well
   */ 
  function setAssetInformation(AssetInformation calldata assetInformation, uint256[] calldata assetCreditRatings) external onlyOwner {

    IOraclesHub(_oracleHub).checkOracleSequence(assetInformation.oracleAddresses);
    
    address assetAddress = assetInformation.assetAddress;
    //require(!inSubRegistry[assetAddress], 'Asset already known in Sub-Registry');
    if (!inSubRegistry[assetAddress]) {
      inSubRegistry[assetAddress] = true;
      assetsInSubRegistry.push(assetAddress);
    }
    assetToInformation[assetAddress] = assetInformation;
    isAssetAddressWhiteListed[assetAddress] = true;
    IMainRegistry(_mainRegistry).addAsset(assetAddress, assetCreditRatings);
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @param assetAddress The address of the asset
   * @param assetId The Id of the asset
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address assetAddress, uint256 assetId) external override view returns (bool) {
    if (isAssetAddressWhiteListed[assetAddress]) {
      if (isIdInRange(assetAddress, assetId)) {
        return true;
      }
    }

    return false;
  }

  /**
   * @notice Checks if the Id for a given token is in the range for which there exists a price feed
   * @param assetAddress The address of the asset
   * @param assetId The Id of the asset
   * @return A boolean, indicating if the Id of the given asset is whitelisted
   */
  function isIdInRange(address assetAddress, uint256 assetId) private view returns (bool) {
    if (assetId >= assetToInformation[assetAddress].idRangeStart && assetId <= assetToInformation[assetAddress].idRangeEnd) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset denominated in USD or
   *                      denominated in a given Numeraire different from USD
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   * @dev The value of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset.
   *      Only one of the two values can be different from 0.
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256 valueInUsd, uint256 valueInNumeraire) {
 
    (valueInUsd, valueInNumeraire) = IOraclesHub(_oracleHub).getRate(assetToInformation[getValueInput.assetAddress].oracleAddresses, getValueInput.numeraire);
  }
}