// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IChainLinkData {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
