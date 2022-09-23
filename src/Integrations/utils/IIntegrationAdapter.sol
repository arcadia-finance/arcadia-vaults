// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity >=0.8.0 <0.9.0;

struct actionAssetsData { 
            address[] assets;
            uint256[] assetIds;
            uint256[] preCallAssetBalances;
            uint256[] minmaxAssetAmounts;
    }

/// @title Integration Adapter interface
/// @author Enzyme Council <security@enzyme.finance>
/// @notice Interface for all integration adapters
interface IIntegrationAdapter {

    function parseAssetsForAction(
        address _vaultProxy,
        bytes4 _selector,
        bytes calldata _encodedCallArgs
    )
        external
        view
        returns (
            actionAssetsData memory spendAssets_,
            actionAssetsData memory incomingAssets_
        );
}