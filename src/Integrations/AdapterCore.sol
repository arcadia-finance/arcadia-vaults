// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IAdapter.sol";
import "./utils/AssetActionData.sol";

/// @title AdapterCore Contract
///
/// @notice A base contract for adapters
abstract contract AdapterCore is IAdapter {
    address internal immutable INTEGRATION_MANAGER;

    modifier onlyIntegrationManager() {
        require(msg.sender == INTEGRATION_MANAGER, "AC: Only the IntegrationManager can call this function");
        _;
    }

    constructor(address _integrationManager) {
        INTEGRATION_MANAGER = _integrationManager;
    }

    /// @dev Helper to decode the _assetData param passed to adapter call
    /// Should return actionData structs for incoming vs outgoing
    // Refactor
    function _decodeActionData(bytes memory _actionData)
        internal
        pure
        returns (actionAssetsData memory outgoingAssets, actionAssetsData memory incomingAssets)
    {
        return abi.decode(_actionData, (actionAssetsData, actionAssetsData));
    }

    /// @notice Gets the `INTEGRATION_MANAGER` variable
    /// @return integrationManager_ The `INTEGRATION_MANAGER` variable value
    function getIntegrationManager() external view returns (address integrationManager_) {
        return INTEGRATION_MANAGER;
    }
}
