/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IStandardERC20PricingModule {
    /**
     * @notice Returns the asset information of an asset.
     * @param asset The contract address of the asset.
     * @return assetUnit The unit (10^decimals) of the asset.
     * @return oracles An array of contract addresses of oracles, to price the asset in USD.
     */
    function getAssetInformation(address asset) external view returns (uint64, address[] memory);
}
