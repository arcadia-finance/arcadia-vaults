// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

struct actionAssetsData {
    address[] assets;
    uint256[] assetIds;
    uint256[] preCallAssetBalances;
    uint256[] postCallAssetBalances;
    uint256[] minmaxAssetAmounts;
    uint256[] assetAmounts;
}
