/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

struct ActionData {
    address[] assets; // Assets addresses
    uint256[] assetIds; // Asset Ids for non-funbale assets
    uint256[] assetAmounts; // Action asset amounts
    uint256[] assetTypes; // Asset types (0 = erc20 ...)
    uint256[] actionBalances; // Account asset balances
}
