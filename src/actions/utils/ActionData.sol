/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

// Struct with information to pass to and from actionHandlers.
struct ActionData {
    address[] assets; // Array of the contract addresses of the assets.
    uint256[] assetIds; // Array of the IDs of the assets.
    uint256[] assetAmounts; // Array with the amounts of the assets.
    uint256[] assetTypes; // Array with the types of the assets.
    uint256[] actionBalances; // Array with the balances of the actionHandler.
}
