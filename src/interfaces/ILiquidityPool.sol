// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface ILiquidityPool {
    function syncInterests() external;

    function borrow(uint256 amount, address vault, address to) external;

    function repay(uint256 amount, address vault) external;

    function debtToken() external returns (address);

    function interestRate() external returns (uint64 interestRate);

    function updateInterestRate(uint64 interestRate) external;

    function asset() external returns (address);

    function processDefault(uint256 assets, uint256 deficit) external;
}
