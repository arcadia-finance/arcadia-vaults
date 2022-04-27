// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IChainLinkData.sol";

import {Printing} from "./utils/Printer.sol";
import {FixedPointMathLib} from './utils/FixedPointMathLib.sol';

/** 
  * @title Oracle Hub
  * @author Arcadia Finance
  * @notice The Oracle Hub stores the adressesses and other necessary information of the Oracles
  * @dev No end-user should directly interact with the Main-registry, only the Main Registry, Sub-Registries or the contract owner
 */ 
contract OracleHub is Ownable {
  using FixedPointMathLib for uint256;

  struct OracleInformation {
    uint64 oracleUnit;
    uint8 baseAssetNumeraire;
    bool baseAssetIsNumeraire;
    string quoteAsset;
    string baseAsset;
    address oracleAddress;
    address quoteAssetAddress;
  }
  
  mapping (address => bool) public inOracleHub;
  mapping (address => OracleInformation) public oracleToOracleInformation;

  /**
   * @notice Constructor
   */
  constructor () {}

  /**
   * @notice Add a new oracle to the Oracle Hub
   * @param oracleInformation A Struct with information about the new Oracle
   * @dev It is not possible to overwrite the information of an existing Oracle in the Oracle Hub
   */
  function addOracle(OracleInformation calldata oracleInformation) external onlyOwner { //Need separate function to edit existing oracles?
    address oracleAddress = oracleInformation.oracleAddress;
    require(!inOracleHub[oracleAddress], 'Oracle already in oracle-hub');
    require(oracleInformation.oracleUnit <= 1000000000000000000, 'Oracle can have maximal 18 decimals');
    inOracleHub[oracleAddress] = true;
    oracleToOracleInformation[oracleAddress] = oracleInformation;
  }

  /**
   * @notice Checks if two input strings are identical, if so returns true
   * @param a The first string to be compared
   * @param b The second string to be compared
   * @return stringsMatch Boolean that returns true if both input strings are equal, and false if both strings are different
   */
  function compareStrings(string memory a, string memory b) internal pure returns (bool stringsMatch) {
      if(bytes(a).length != bytes(b).length) {
          return false;
      } else {
          stringsMatch = keccak256(bytes(a)) == keccak256(bytes(b));
      }
  }

  /**
   * @notice Checks if a series of oracles , if so returns true
   * @param oracleAdresses An array of addresses of oracle contracts
   * @dev Function will do nothing if all checks pass, but reverts if at least one check fails.
   *      The following checks are performed:
   *      The oracle-address must be previously added to the Oracle-Hub.
   *      The last oracle in the series must have USD as base-asset.
   *      The Base-asset of all oracles must be equal to the quote-asset of the next oracle (except for the last oracle in the series).
   */
  function checkOracleSequence (address[] memory oracleAdresses) external view {
    uint256 oracleAdressesLength = oracleAdresses.length;
    require(oracleAdressesLength <= 3, "Oracle seq. cant be longer than 3");
    for (uint256 i; i < oracleAdressesLength;) {
      require(inOracleHub[oracleAdresses[i]], "Unknown oracle");
      //Add test that in all other cases, the quote asset of next oracle matches base asset of previous oracle
      if (i > 0) {
        require(compareStrings(oracleToOracleInformation[oracleAdresses[i-1]].baseAsset, oracleToOracleInformation[oracleAdresses[i]].quoteAsset), "qAsset doesnt match with bAsset of prev oracle");
      }
      //Add test that base asset of last oracle is USD
      if (i == oracleAdressesLength-1) {
        require(compareStrings(oracleToOracleInformation[oracleAdresses[i]].baseAsset, "USD"), "Last oracle does not have USD as bAsset");
      }
      unchecked {++i;} 
    }

  }

  /**
   * @notice Returns the exchange rate of a certain asset, denominated in USD or in another Numeraire
   * @param oracleAdresses An array of addresses of oracle contracts
   * @param numeraire The Numeraire (base-asset) in which the exchange rate is ideally expressed
   * @return rateInUsd The exchange rate of the asset denominated in USD with 18 Decimals precision
   * @return rateInNumeraire The exchange rate of the asset denominated in a Numeraire different from USD with 18 Decimals precision
   * @dev The Function will loop over all oracles-addresses and find the total exchange rate of the asset by
   *      multiplying the intermediate exchangerates (max 3) with eachother. Exchange rates can be with any Decimals precision, but smaller than 18.
   *      All intermediate exchange rates are calculated with a precision of 18 decimals and rounded down.
   *      Todo: check precision when multiplying multiple small rates -> go to 27 decimals precision??
   *      The exchange rate of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset
   *      Function will overflow if any of the intermediate or the final exchange rate overflows
   *      Example of 3 oracles with R1 the first exchange rate with D1 decimals and R2 the second exchange rate with D2 decimals R3...
   *        First intermediate rate will overflow when R1 * 10**18 > MAXUINT256
   *        Second rate will overflow when R1 * R2 * 10**(18 - D1) > MAXUINT256
   *        Third and final exchange rate will overflow when R1 * R2 * R3 * 10**(18 - D1 - D2) > MAXUINT256
   */
  function getRate(address[] memory oracleAdresses, uint256 numeraire) public view returns (uint256, uint256) {

    //Scalar 1 with 18 decimals
    uint256 rate = FixedPointMathLib.WAD;
    int256 tempRate;

    uint256 oraclesLength = oracleAdresses.length;

    //taking into memory, saves 209 gas
    address oracleAddressAtIndex;
    for (uint256 i; i < oraclesLength;) {
      oracleAddressAtIndex = oracleAdresses[i];
      (, tempRate,,,) = IChainLinkData(oracleToOracleInformation[oracleAddressAtIndex].oracleAddress).latestRoundData();
      require(tempRate >= 0, "Negative oracle price");

      rate = rate.mulDivDown(uint256(tempRate), oracleToOracleInformation[oracleAddressAtIndex].oracleUnit);

      if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetIsNumeraire && oracleToOracleInformation[oracleAddressAtIndex].baseAssetNumeraire == 0) {
        //If rate is expressed in USD, break loop and return rate expressed in numeraire
        return (rate, 0);
      } else if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetIsNumeraire && oracleToOracleInformation[oracleAddressAtIndex].baseAssetNumeraire == numeraire) {
        //If rate is expressed in numeraire, break loop and return rate expressed in numeraire
        return (0, rate);
      }
      unchecked {++i;}
    }
    revert('No oracle with USD or numeraire as bAsset');
  }

}

