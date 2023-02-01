// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC4626 {
    function asset() external view returns (address);

    function decimals() external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);
}
