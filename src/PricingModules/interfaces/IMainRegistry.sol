/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IMainRegistry {
    /**
     * @notice Returns number of basecurrencies.
     * @return counter the number of basecurrencies.
     */
    function baseCurrencyCounter() external view returns (uint256);

    /**
     * @notice Add a new asset to the Main Registry.
     * @param asset The address of the asset.
     * @param assetType Identifier for the type of the asset.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    function addAsset(address asset, uint256 assetType) external;
}
