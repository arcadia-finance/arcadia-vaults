/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

struct actionAssetsData {
    address[] assets; // Assets addresses
    uint256[] assetIds; // Arcadia Protocol asset ids of asset types (0 = erc20 ...)
    uint256[] assetAmounts; // Action asset amounts
    uint256[] assetTypes; // Asset types (0 = erc20 ...)
    uint256[] preActionBalances; // Account asset balances pre action
}
