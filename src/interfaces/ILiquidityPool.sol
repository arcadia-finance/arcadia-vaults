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

    function liquidateVault(address vault, uint256 debt) external;

    function settleLiquidation(uint256 default_, uint256 deficit) external;
}
