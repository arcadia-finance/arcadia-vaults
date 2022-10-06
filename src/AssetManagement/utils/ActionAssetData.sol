/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

struct actionAssetsData {
    address[] assets; // Assets addresses
    uint256[] assetIds; // Arcadia Protocol asset ids (internal ids given to arcadia's whitelisted assets)
    uint256[] assetAmounts; // Action asset amounts
    uint256[] preActionBalances; // Account asset balances pre action
}