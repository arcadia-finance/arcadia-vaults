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

  address public factory;
  address public mainRegistry;

  struct TokenInfo {
    address[] tokenAddresses;
    uint256[] tokenIds;
    uint256[] tokenAmounts;
    uint256[] tokenTypes;
  }

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

  /**
   * @notice Swaps a list of input tokens for a list of output tokens
   * @dev Function swaps n input tokens for m output tokens, tokens are withdrawn and deposited back into the vault
   *      The exchange is mocked, instead of actually swapping tokens, it burns the incoming tokens and mints the outgoing tokens
   *      The exchange rates are fixed (no slippage is taken into account) and live exchange rates from mainnet are used
   *      If the input amount is bigger than the output amount, the difference is deposited in the token pegged to the numeraire.
   * @param tokenInfoInput Struct for all input tokens, following lists need to be passed:
   *        - The token addresses
   *        - The ids, for tokens without id (erc20) any id can be passed
   *        - The amounts
   *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
   * @param tokenInfoOutput For all output tokens, following lists need to be passed:
   *        - The token addresses
   *        - The ids, for tokens without id (erc20) any id can be passed
   *        - The amounts
   *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
   * @param vaultId Id of the vault
   */
  function swapExactTokensForTokens(TokenInfo calldata tokenInfoInput, TokenInfo calldata tokenInfoOutput, uint256 vaultId) external {
    require(msg.sender == IERC721(factory).ownerOf(vaultId), "You are not the owner");

    address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
    (,,,,,uint8 numeraire) = IVaultPaperTrading(vault).debt();

    uint256 totalValueIn = IMainRegistry(mainRegistry).getTotalValue(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, numeraire);
    uint256 totalValueOut = IMainRegistry(mainRegistry).getTotalValue(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, numeraire);
    require(totalValueIn >= totalValueOut, "Not enough funds");

    IVaultPaperTrading(vault).withdraw(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, tokenInfoInput.tokenTypes);
    _burn(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, tokenInfoInput.tokenTypes);
    _mint(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, tokenInfoOutput.tokenTypes);
    IVaultPaperTrading(vault).deposit(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, tokenInfoOutput.tokenTypes);

    if (totalValueIn > totalValueOut) {
      uint256 amountNumeraire = totalValueIn - totalValueOut;
      address stable = IVaultPaperTrading(vault)._stable();
      _mintERC20(stable, amountNumeraire);
      IVaultPaperTrading(vault).depositERC20(stable, amountNumeraire);
    }

  }

  /**
   * @notice Swaps numeraire for a list of output tokens
   * @dev Function swaps numeraire for n output tokens
   *      The exchange is mocked, instead of actually swapping tokens, it burns the incoming numeraire and mints the outgoing tokens
   *      The exchange rates are fixed (no slippage is taken into account) and live exchange rates from mainnet are used
   * @param tokenInfoOutput For all output tokens, following lists need to be passed:
   *        - The token addresses
   *        - The ids, for tokens without id (erc20) any id can be passed
   *        - The amounts
   *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
   * @param vaultId Id of the vault
   */
  function swapNumeraireForExactTokens(TokenInfo calldata tokenInfoOutput, uint256 vaultId) external {
    require(msg.sender == IERC721(factory).ownerOf(vaultId), "You are not the owner");

    address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
    (,,,,,uint8 numeraire) = IVaultPaperTrading(vault).debt();
    address stable = IVaultPaperTrading(vault)._stable();

    uint256 totalValue = IMainRegistry(mainRegistry).getTotalValue(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, numeraire);

    IVaultPaperTrading(vault).withdrawERC20(stable, totalValue);
    _burnERC20(stable, totalValue);
    _mint(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, tokenInfoOutput.tokenTypes);
    IVaultPaperTrading(vault).deposit(tokenInfoOutput.tokenAddresses, tokenInfoOutput.tokenIds, tokenInfoOutput.tokenAmounts, tokenInfoOutput.tokenTypes);
  }

  /**
   * @notice Swaps a list of input tokens for numeraire
   * @dev Function swaps n input tokens for numeraire
   *      The exchange is mocked, instead of actually swapping tokens, it burns the incoming numeraire and mints the outgoing tokens
   *      The exchange rates are fixed (no slippage is taken into account) and live exchange rates from mainnet are used
   * @param tokenInfoInput Struct for all input tokens, following lists need to be passed:
   *        - The token addresses
   *        - The ids, for tokens without id (erc20) any id can be passed
   *        - The amounts
   *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
   * @param vaultId Id of the vault
   */
  function swapExactTokensForNumeraire(TokenInfo calldata tokenInfoInput, uint256 vaultId) external {
    require(msg.sender == IERC721(factory).ownerOf(vaultId), "You are not the owner");

    address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
    (,,,,,uint8 numeraire) = IVaultPaperTrading(vault).debt();
    address stable = IVaultPaperTrading(vault)._stable();

    uint256 totalValue = IMainRegistry(mainRegistry).getTotalValue(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, numeraire);

    IVaultPaperTrading(vault).withdraw(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, tokenInfoInput.tokenTypes);
    _burn(tokenInfoInput.tokenAddresses, tokenInfoInput.tokenIds, tokenInfoInput.tokenAmounts, tokenInfoInput.tokenTypes);
    _mintERC20(stable, totalValue);
    IVaultPaperTrading(vault).depositERC20(stable, totalValue);
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