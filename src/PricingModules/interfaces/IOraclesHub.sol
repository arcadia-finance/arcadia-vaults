/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IOraclesHub {
    /**
     * @notice Verifies whether a sequence of oracles complies with a predetermined set of criteria.
     * @param oracles Array of contract addresses of oracles.
     * @param asset The contract address of the base-asset.
     */
    function checkOracleSequence(address[] memory oracles, address asset) external view;

    /**
     * @notice Returns the state of an oracle.
     * @param oracle The contract address of the oracle to be checked.
     * @return boolean indicating if the oracle is active or not.
     */
    function isActive(address oracle) external view returns (bool);

    /**
     * @notice Returns the rate of a certain asset, denominated in USD or in another BaseCurrency.
     * @param oracles Array of contract addresses of oracles.
     * @param baseCurrency The BaseCurrency in which the rate is ideally expressed.
     * @return rateInUsd The rate of the asset denominated in USD, with 18 Decimals precision.
     * @return rateInBaseCurrency The rate of the asset denominated in a BaseCurrency different from USD, with 18 Decimals precision.
     */
    function getRate(address[] memory oracles, uint256 baseCurrency) external view returns (uint256, uint256);
}
