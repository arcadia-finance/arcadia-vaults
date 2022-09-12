// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC4626 {
    function asset() external view returns (address assetTokenAddress);

    function decimals() external view returns (uint256 decimals);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function maxWithdraw(address owner) external view returns (uint256 assets);
}