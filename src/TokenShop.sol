// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IMainRegistry.sol";

import {Printing} from "./utils/Printer.sol";
import {FixedPointMathLib} from './utils/FixedPointMathLib.sol';

/** 
  * @title Token Shop
  * @author Arcadia Finance
  * @notice Mocked Exchange for the Arcadia Paper Trading Game
  * @dev For testnet purposes only
 */ 

contract TokenShop is Ownable {
  using FixedPointMathLib for uint256;

  address private factory;
  address private mainRegistry;

  constructor (address _mainRegistry) {
    mainRegistry = _mainRegistry;
  }

  /**
   * @dev Sets the new Factory address
   * @param _factory The address of the Factory
   */
  function setFactory(address _factory) public {
    factory = _factory;
  }

  function swapExactTokensForTokens(address[] calldata tokensIn, uint256[] calldata idsIn ,uint256[] calldata amountsIn, address[] calldata tokenOut, uint256[] calldata idsOut, uint256[] calldata amountsOut, uint256 vaultId) external {
    require(msg.sender == IERC721(factory).ownerOf(vaultId), "You are not the owner");
    address vault = IFactory(factory).getVaultAddress(vaultId);
    (,,,,,uint8 numeraire) = IVault(vault).debt();

    uint256 totalValueIn = IMainRegistry(mainRegistry).getTotalValue(tokensIn, idsIn, amountsIn, numeraire);
    uint256 totalValuesOut = IMainRegistry(mainRegistry).getTotalValue(tokenOut, idsOut, amountsOut, numeraire);
    require (totalValueIn >= totalValuesOut, "Not enough funds");

    //Ivault withdraw
    //burn tokens in
    //mint tokens out
    //mint (tokensIn - tokensOut) in numeraire
    //Ivault deposit
  }


}