// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IReserveFund {
    function withdraw(
        uint256 amount,
        address tokenAddress,
        address to
    ) external returns (bool);
}
