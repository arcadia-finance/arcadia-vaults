// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Sub-registry for Uniswap V2 LP tokens
  * @author Arcadia Finance
  * @notice The UniswapV2SubRegistry stores pricing logic and basic information for Uniswap V2 LP tokens
  * @dev No end-user should directly interact with the UniswapV2SubRegistry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract UniswapV2SubRegistry is SubRegistry {
  using FixedPointMathLib for uint256;

  uint256 public constant poolUnit = 1000000000000000000; //All Uniswap V2 pool-tokens have 18 decimals

  struct AssetInformation {
    uint64 token0Unit;
    uint64 token1Unit;
    address pool;
    address token0;
    address token1;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor (address mainRegistry, address oracleHub) SubRegistry(mainRegistry, oracleHub) {}

  /**
   * @notice Returns the value of a certain asset, denominated in a given Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256 valueInUsd, uint256 valueInNumeraire) {

    address[] memory tokens = new address[](2);
    tokens[0] = assetToInformation[getValueInput.assetAddress].token0;
    tokens[1] = assetToInformation[getValueInput.assetAddress].token1;
    uint256[] memory tokenUnits = new uint256[](2);
    tokenUnits[0] = assetToInformation[getValueInput.assetAddress].token0Unit;
    tokenUnits[1] = assetToInformation[getValueInput.assetAddress].token1Unit;

    uint256[] memory tokenRates = IMainRegistry(oracleHub).getListOfValuesPerAsset(tokens, new uint256[](2), tokenUnits, getValueInput.numeraire);

    

  }

}