// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function decimals() external view returns (uint256);
}
