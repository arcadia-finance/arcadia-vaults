// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Sub-registry for Standard ERC20 tokens
  * @author Arcadia Finance
  * @notice The StandardERC20Registry stores pricing logic and basic information for ERC20 tokens for which a direct price feeds exists
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC20Registry is SubRegistry {
  using FixedPointMathLib for uint256;

  struct AssetInformation {
    uint64 assetUnit;
    address assetAddress;
    address[] oracleAddresses;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor (address mainRegistry, address oracleHub) SubRegistry(mainRegistry, oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }

  /**
   * @notice Add a new asset to the StandardERC20Registry, or overwrite an existing one
   * @param assetInformation A Struct with information about the asset 
   * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires
   * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
   *  or the list must have lenth 0. If the list has length zero, the credit ratings of the asset for all numeraires is
   *  is initiated as credit rating with index 0 by default (worst credit rating)
   * @dev The asset needs to be added/overwritten in the Main-Registry as well
   */
  function setAssetInformation(AssetInformation calldata assetInformation, uint256[] calldata assetCreditRatings) external onlyOwner {
    
    IOraclesHub(_oracleHub).checkOracleSequence(assetInformation.oracleAddresses);

    address assetAddress = assetInformation.assetAddress;
    require(assetInformation.assetUnit <= 10**18, 'Asset can have maximal 18 decimals');
    if (!inSubRegistry[assetAddress]) {
      inSubRegistry[assetAddress] = true;
      assetsInSubRegistry.push(assetAddress);
    }
    assetToInformation[assetAddress] = assetInformation;
    isAssetAddressWhiteListed[assetAddress] = true;
    IMainRegistry(_mainRegistry).addAsset(assetAddress, assetCreditRatings);
  }

  /**
   * @notice Returns the information that is stored in the Sub-registry for a given asset
   * @dev struct is not taken into memory; saves 6613 gas
   * @param asset The Token address of the asset
   * @return assetDecimals The number of decimals of the asset
   * @return assetAddress The Token address of the asset
   * @return oracleAddresses The list of addresses of the oracles to get the exchange rate of the asset in USD
   */
  function getAssetInformation(address asset) public view returns (uint64, address, address[] memory) {
    return (assetToInformation[asset].assetUnit, assetToInformation[asset].assetAddress, assetToInformation[asset].oracleAddresses);
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @param assetAddress The address of the asset
   * @dev For each token address, a corresponding id at the same index should be present,
   *      for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address assetAddress, uint256) external override view returns (bool) {
    if (isAssetAddressWhiteListed[assetAddress]) {
      return true;
    }

    return false;
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset denominated in USD or
   *  denominated in a given Numeraire different from USD
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   * @dev The value of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset.
   *      Only one of the two values can be different from 0.
   *      Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256, uint256) {
    uint256 value;
    uint256 rateInUsd;
    uint256 rateInNumeraire;

    //Will return empty struct when asset is not first added to subregisrty -> still return a value without error
    //In reality however call will always pass via mainregistry, that already does the check
    //ToDo

    (rateInUsd, rateInNumeraire) = IOraclesHub(_oracleHub).getRate(assetToInformation[getValueInput.assetAddress].oracleAddresses, getValueInput.numeraire);

    if (rateInNumeraire > 0) {
      value = (getValueInput.assetAmount).mulDivDown(rateInNumeraire, assetToInformation[getValueInput.assetAddress].assetUnit);
      return (0, value);
    } else {
      value = (getValueInput.assetAmount).mulDivDown(rateInUsd, assetToInformation[getValueInput.assetAddress].assetUnit);
      return (value, 0);
    }
        
  }

}