/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IOraclesHub {
    function getRate(address[] memory, uint256)
        external
        view
        returns (uint256, uint256);

    function checkOracleSequence(address[] memory oracleAdresses) external view;
}
