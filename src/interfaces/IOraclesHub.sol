// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IOraclesHub {
    function getRate(address[] memory, uint256)
        external
        view
        returns (uint256, uint256);

    function checkOracleSequence(address[] memory oracleAdresses) external view;
}
