// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract StableOracle is Ownable {

    uint80 private roundId;
    int256 private answer;
    uint256 private startedAt;
    uint256 private updatedAt;
    uint80 private answeredInRound;

    uint8 public decimals;
    string public description;

    constructor (uint8 _decimals, string memory _description) {
        decimals = _decimals;
        description = _description;
        answer = int256(10 ** _decimals);
    }

    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }



}