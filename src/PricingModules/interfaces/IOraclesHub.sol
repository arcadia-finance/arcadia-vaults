/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity ^0.8.13;

interface IOraclesHub {
    /**
     * @notice Checks if a series of oracles adheres to a predefined ruleset
     * @param oracles An array of addresses of oracle contracts
     * @param asset The contract address of the base-asset.
     */
    function checkOracleSequence(address[] memory oracles, address asset) external view;

    /**
     * @notice Returns the exchange rate of a certain asset, denominated in USD or in another BaseCurrency
     * @param oracles An array of addresses of oracle contracts
     * @param baseCurrency The BaseCurrency in which the exchange rate is ideally expressed
     * @return rateInUsd The exchange rate of the asset denominated in USD, integer with 18 Decimals precision
     * @return rateInBaseCurrency The exchange rate of the asset denominated in a BaseCurrency different from USD, integer with 18 Decimals precision
     */
    function getRate(address[] memory oracles, uint256 baseCurrency) external view returns (uint256, uint256);
}
