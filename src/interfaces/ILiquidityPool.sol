// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface ILiquidityPool {
    function syncInterests() external;

    function borrow(uint256 amount, address vault, address to) external;

    function repay(uint256 amount, address vault) external;
}
