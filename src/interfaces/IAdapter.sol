// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../Integrations/utils/AssetActionData.sol";

/// @title Integration Adapter interface

interface IAdapter {
    function parseAssetsForAction(address _vaultProxy, bytes4 _selector, bytes calldata _encodedCallArgs)
        external
        view
        returns (actionAssetsData memory spendAssets_, actionAssetsData memory incomingAssets_);
}
