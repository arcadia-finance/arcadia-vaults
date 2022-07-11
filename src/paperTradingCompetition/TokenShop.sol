/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IERC20PaperTrading.sol";
import "./interfaces/IERC721PaperTrading.sol";
import "./interfaces/IERC1155PaperTrading.sol";
import "./interfaces/IVaultPaperTrading.sol";
import "./interfaces/IFactoryPaperTrading.sol";
import "./../interfaces/IMainRegistry.sol";

import {FixedPointMathLib} from "./../utils/FixedPointMathLib.sol";

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

    constructor(address _mainRegistry) {
        mainRegistry = _mainRegistry;
    }

    /**
     * @dev Sets the new Factory address
     * @param _factory The address of the Factory
     */
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    /**
     * @notice Swaps numeraire for a list of output tokens
     * @dev Function swaps numeraire for n output tokens
     *      The exchange is mocked, instead of actually swapping tokens, it burns the incoming numeraire and mints the outgoing tokens
     *      The exchange rates are fixed (no slippage is taken into account) and live exchange rates from mainnet are used
     * @param tokenInfo For all output tokens, following lists need to be passed:
     *        - The token addresses
     *        - The ids, for tokens without id (erc20) any id can be passed
     *        - The amounts
     *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
     * @param vaultId Id of the vault
     */
    function swapNumeraireForExactTokens(
        TokenInfo calldata tokenInfo,
        uint256 vaultId
    ) external {
        require(
            msg.sender == IERC721(factory).ownerOf(vaultId),
            "TS_SNFET: You are not the owner"
        );

        uint256 tokenAddressesLength = tokenInfo.tokenAddresses.length;

        require(
            tokenAddressesLength == tokenInfo.tokenIds.length &&
                tokenAddressesLength == tokenInfo.tokenAmounts.length &&
                tokenAddressesLength == tokenInfo.tokenTypes.length,
            "TS_SNFET: Length mismatch"
        );

        address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
        (uint128 openDebt, , , , , uint8 numeraire) = IVaultPaperTrading(vault)
            .debt();
        address stable = IVaultPaperTrading(vault)._stable();

        uint256 totalValue = IMainRegistry(mainRegistry).getTotalValue(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            numeraire
        );

        IVaultPaperTrading(vault).withdrawERC20(stable, totalValue);
        _burnERC20(stable, totalValue);
        _mint(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            tokenInfo.tokenTypes
        );
        _approve(vault, tokenInfo.tokenAddresses, tokenInfo.tokenTypes);
        IVaultPaperTrading(vault).deposit(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            tokenInfo.tokenTypes
        );

        if (openDebt != 0) {
            IVaultPaperTrading(vault).setYearlyInterestRate();
        }
    }

    /**
     * @notice Swaps a list of input tokens for numeraire
     * @dev Function swaps n input tokens for numeraire
     *      The exchange is mocked, instead of actually swapping tokens, it burns the incoming numeraire and mints the outgoing tokens
     *      The exchange rates are fixed (no slippage is taken into account) and live exchange rates from mainnet are used
     * @param tokenInfo Struct for all input tokens, following lists need to be passed:
     *        - The token addresses
     *        - The ids, for tokens without id (erc20) any id can be passed
     *        - The amounts
     *        - The token types (0 = ERC20, 1 = ERC721, 2 = ERC1155, Any other number = failed tx)
     * @param vaultId Id of the vault
     */
    function swapExactTokensForNumeraire(
        TokenInfo calldata tokenInfo,
        uint256 vaultId
    ) external {
        require(
            msg.sender == IERC721(factory).ownerOf(vaultId),
            "TS_SETFN: You are not the owner"
        );

        uint256 tokenAddressesLength = tokenInfo.tokenAddresses.length;

        require(
            tokenAddressesLength == tokenInfo.tokenIds.length &&
                tokenAddressesLength == tokenInfo.tokenAmounts.length &&
                tokenAddressesLength == tokenInfo.tokenTypes.length,
            "TS_SETFN: Length mismatch"
        );

        address vault = IFactoryPaperTrading(factory).getVaultAddress(vaultId);
        (uint128 openDebt, , , , , uint8 numeraire) = IVaultPaperTrading(vault)
            .debt();
        address stable = IVaultPaperTrading(vault)._stable();

        uint256 totalValue = IMainRegistry(mainRegistry).getTotalValue(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            numeraire
        );

        IVaultPaperTrading(vault).withdraw(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            tokenInfo.tokenTypes
        );
        _burn(
            tokenInfo.tokenAddresses,
            tokenInfo.tokenIds,
            tokenInfo.tokenAmounts,
            tokenInfo.tokenTypes
        );
        _mintERC20(stable, totalValue);
        _approveERC20(stable, vault);
        IVaultPaperTrading(vault).depositERC20(stable, totalValue);

        if (openDebt != 0) {
            IVaultPaperTrading(vault).setYearlyInterestRate();
        }
    }

    function _mint(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) internal {
        for (uint256 i; i < assetAddresses.length; ) {
            if (assetTypes[i] == 0) {
                _mintERC20(assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _mintERC721(assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _mintERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                require(false, "Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    function _burn(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) internal {
        for (uint256 i; i < assetAddresses.length; ) {
            if (assetTypes[i] == 0) {
                _burnERC20(assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _burnERC721(assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _burnERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                require(false, "Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    function _approve(
        address vault,
        address[] calldata assetAddresses,
        uint256[] calldata assetTypes
    ) internal {
        for (uint256 i; i < assetAddresses.length; ) {
            if (assetTypes[i] == 0) {
                _approveERC20(assetAddresses[i], vault);
            } else if (assetTypes[i] == 1) {
                _approveERC721(assetAddresses[i], vault);
            } else if (assetTypes[i] == 2) {
                _approveERC1155(assetAddresses[i], vault);
            } else {
                require(false, "Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    function _mintERC20(address tokenAddress, uint256 tokenAmount) internal {
        IERC20PaperTrading(tokenAddress).mint(address(this), tokenAmount);
    }

    function _mintERC721(address tokenAddress, uint256 tokenId) internal {
        IERC721PaperTrading(tokenAddress).mint(address(this), tokenId);
    }

    function _mintERC1155(
        address tokenAddress,
        uint256 tokenId,
        uint256 tokenAmount
    ) internal {
        IERC1155PaperTrading(tokenAddress).mint(
            address(this),
            tokenId,
            tokenAmount
        );
    }

    function _burnERC20(address tokenAddress, uint256 tokenAmount) internal {
        IERC20PaperTrading(tokenAddress).burn(tokenAmount);
    }

    function _burnERC721(address tokenAddress, uint256 tokenId) internal {
        IERC721PaperTrading(tokenAddress).burn(tokenId);
    }

    function _burnERC1155(
        address tokenAddress,
        uint256 tokenId,
        uint256 tokenAmount
    ) internal {
        IERC1155PaperTrading(tokenAddress).burn(tokenId, tokenAmount);
    }

    function _approveERC20(address tokenAddress, address spender) internal {
        IERC20PaperTrading(tokenAddress).approve(spender, type(uint256).max);
    }

    function _approveERC721(address tokenAddress, address spender) internal {
        IERC721PaperTrading(tokenAddress).setApprovalForAll(spender, true);
    }

    function _approveERC1155(address tokenAddress, address spender) internal {
        IERC1155PaperTrading(tokenAddress).setApprovalForAll(spender, true);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
