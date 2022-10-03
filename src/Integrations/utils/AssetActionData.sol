// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

struct actionAssetsData {
    address[] assets; // Assets addresses
    uint256[] assetIds; // Protocol asset ids (internal ids given to arcadia's whitelisted assets)
    uint256[] assetAmounts; // Effective action amounts (TODO: redundant?)
    uint256[] limitAssetAmounts; // Maximum outgoing or minimum incoming
    uint256[] preCallAssetBalances; // Account asset balances pre action
    uint256 preCallCollThresh; // Pre action coll tresh
}
