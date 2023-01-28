// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface ILendingPool {
    function syncInterests() external;

    function borrow(uint256 amount, address vault, address to, bytes3 ref) external;

    function repay(uint256 amount, address vault) external;

    function debtToken() external returns (address);

    function interestRate() external returns (uint64 interestRate);

    function updateInterestRate(uint64 interestRate) external;

    function asset() external returns (address);

    function liquidateVault(address vault, uint256 debt) external;

    function settleLiquidation(
        address vault,
        address originalOwner,
        uint256 badDebt,
        uint256 liquidationInitiatorReward,
        uint256 liquidationPenalty,
        uint256 remainder
    ) external;
}
