// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../utils/UniswapV2ActionsMixin.sol";
import "../AdapterCore.sol";

/// @title UniswapV2ExchangeAdapter Contract
/// @author Enzyme Council <security@enzyme.finance>
/// @notice Adapter for interacting with Uniswap v2 swaps
contract UniswapV2ExchangeAdapter is AdapterCore, UniswapV2ActionsMixin {
    constructor(address _integrationManager, address _router)
        AdapterCore(_integrationManager)
        UniswapV2ActionsMixin(_router)
    {}

    /// @notice Trades assets on Uniswap
    /// @param _vaultProxy The VaultProxy of the calling fund
    /// @param _actionData Data specific to this action
    function takeOrder(address _vaultProxy, bytes calldata _actionData, bytes calldata)
        external
        onlyIntegrationManager
    {
        (address[] memory path, uint256 outgoingAssetAmount, uint256 minIncomingAssetAmount) =
            __decodeTakeOrderCallArgs(_actionData);

        __uniswapV2Swap(_vaultProxy, outgoingAssetAmount, minIncomingAssetAmount, path);
    }

    /////////////////////////////
    // PARSE ASSETS FOR METHOD //
    /////////////////////////////

    /// @notice Parses the expected assets in a particular action
    /// @param _selector The function selector for the callOnIntegration
    /// @param _actionData Data specific to this action
    /// the adapter access to spend assets (`None` by default)

    function parseAssetsForAction(address, bytes4 _selector, bytes calldata _actionData)
        external
        view
        override
        returns (actionAssetsData memory spendAssets_, actionAssetsData memory incomingAssets_)
    {
        // require(_selector == TAKE_ORDER_SELECTOR, "parseAssetsForAction: _selector invalid");
        //ToDO: check selector things
        return _parseAssetsForSwap(_actionData);
    }

    /// @dev Helper function to parse spend and incoming assets from encoded call args
    /// during takeOrder() calls
    function _parseAssetsForSwap(bytes calldata _actionData)
        private
        pure
        returns (actionAssetsData memory outgoingAssets_, actionAssetsData memory incomingAssets_)
    {
        (address[] memory path, uint256 outgoingAssetAmount, uint256 minIncomingAssetAmount) =
            __decodeTakeOrderCallArgs(_actionData);

        require(path.length >= 2, "AUV2: _path must be >= 2");

        outgoingAssets_.assets = new address[](1);
        outgoingAssets_.assets[0] = path[0];
        outgoingAssets_.assetAmounts = new uint256[](1);
        outgoingAssets_.assetAmounts[0] = outgoingAssetAmount; 

        incomingAssets_.assets = new address[](1);
        incomingAssets_.assets[0] = path[path.length - 1];
        incomingAssets_.limitAssetAmounts = new uint256[](1);
        incomingAssets_.limitAssetAmounts[0] = minIncomingAssetAmount;

        return (outgoingAssets_, incomingAssets_);
    }

    // PRIVATE FUNCTIONS

    /// @dev Helper to decode the take order encoded call arguments
    function __decodeTakeOrderCallArgs(bytes memory _actionData)
        private
        pure
        returns (address[] memory path_, uint256 outgoingAssetAmount_, uint256 minIncomingAssetAmount_)
    {
        return abi.decode(_actionData, (address[], uint256, uint256));
    }
}
