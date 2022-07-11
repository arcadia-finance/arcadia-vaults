/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IRM {
    function getYearlyInterestRate(
        uint256[] memory ValuesPerCreditRating,
        uint256 minCollValue
    ) external view returns (uint64);
}
