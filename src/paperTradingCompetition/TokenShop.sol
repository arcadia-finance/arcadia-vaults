// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IERC20PaperTrading.sol";
import "./interfaces/IERC721PaperTrading.sol";
import "./interfaces/IERC1155PaperTrading.sol";
import "./interfaces/IVaultPaperTrading.sol";
import "./interfaces/IFactoryPaperTrading.sol";
import "./../interfaces/IMainRegistry.sol";

import {Printing} from "./../utils/Printer.sol";
import {FixedPointMathLib} from './../utils/FixedPointMathLib.sol';

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

  function swapExactTokensForTokens(
      address[] calldata tokensIn,
      uint256[] calldata idsIn,
      uint256[] calldata amountsIn,
      uint256[] calldata assetTypesIn,
      address[] calldata tokensOut,
      uint256[] calldata idsOut,
      uint256[] calldata amountsOut,
      uint256[] calldata assetTypesOut,
      uint256 vaultId
    ) external {
    require(msg.sender == IERC721(factory).ownerOf(vaultId), "You are not the owner");
    address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
    (,,,,,uint8 numeraire) = IVaultPaperTrading(vault).debt();

    uint256 totalValueIn = IMainRegistry(mainRegistry).getTotalValue(tokensIn, idsIn, amountsIn, numeraire);
    uint256 totalValueOut = IMainRegistry(mainRegistry).getTotalValue(tokensOut, idsOut, amountsOut, numeraire);
    require (totalValueIn >= totalValueOut, "Not enough funds");

    IVaultPaperTrading(vault).withdraw(tokensIn, idsIn, amountsIn, assetTypesIn);
    _burn(tokensIn, idsIn, amountsIn, assetTypesIn);
    _mint(tokensOut, idsOut, amountsOut, assetTypesOut);
    IVaultPaperTrading(vault).deposit(tokensOut, idsOut, amountsOut, assetTypesOut);

    if (totalValueIn > totalValueOut) {
      uint256 amountNumeraire = totalValueIn - totalValueOut;
      address stable = IVaultPaperTrading(vault)._stable();
      _mintERC20(stable, amountNumeraire);

      address[] memory stableArr = new address[](1);
      uint256[] memory stableIdArr = new uint256[](1);
      uint256[] memory stableAmountArr = new uint256[](1);
      uint256[] memory stableTypeArr = new uint256[](1);

      stableArr[0] = stable;
      stableIdArr[0] = 0; //can delete
      stableAmountArr[0] = amountNumeraire;
      stableTypeArr[0] = 0; //can delete

      IVaultPaperTrading(vault).deposit(stableArr, stableIdArr, stableAmountArr, stableTypeArr);
    }

  }

  function _mint(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) internal {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    
    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _mintERC20(assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _mintERC721(assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _mintERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  function _burn(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) internal {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    
    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _burnERC20(assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _burnERC721(assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _burnERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  function _mintERC20(address tokenAddress, uint256 tokenAmount) internal {
    IERC20PaperTrading(tokenAddress).mint(address(this), tokenAmount);
  }

  function _mintERC721(address tokenAddress, uint256 tokenId) internal {
    IERC721PaperTrading(tokenAddress).mint(address(this), tokenId);
  }

  function _mintERC1155(address tokenAddress, uint256 tokenId, uint256 tokenAmount) internal {
    IERC1155PaperTrading(tokenAddress).mint(address(this), tokenId, tokenAmount);
  }

  function _burnERC20(address tokenAddress, uint256 tokenAmount) internal {
    IERC20PaperTrading(tokenAddress).burn(tokenAmount);
  }

  function _burnERC721(address tokenAddress, uint256 tokenId) internal {
    IERC721PaperTrading(tokenAddress).burn(tokenId);
  }

  function _burnERC1155(address tokenAddress, uint256 tokenId, uint256 tokenAmount) internal {
    IERC1155PaperTrading(tokenAddress).burn(tokenId, tokenAmount);
  }

}