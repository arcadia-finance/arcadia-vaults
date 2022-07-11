/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity ^0.8.13;

interface IReserveFund {
    function withdraw(
        uint256 amount,
        address tokenAddress,
        address to
    ) external returns (bool);
}
