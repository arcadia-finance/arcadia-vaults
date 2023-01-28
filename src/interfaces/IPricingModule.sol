/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IPricingModule {
    struct GetValueInput {
        address assetAddress; //The contract address of the asset
        uint256 assetId; //The Id of the asset
        uint256 assetAmount; //The Amount of tokens
        uint256 baseCurrency; //Identifier of the BaseCurrency in which the value is ideally expressed
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param input A Struct with all the information neccessary to get the value of an asset
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
     */
    function getValue(GetValueInput memory input) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Processes the deposit of tokens if it is white-listed
     * @param asset The address of the asset
     * @param id The Id of the asset where applicable
     * @param amount The amount of tokens
     */
    function processDeposit(address asset, uint256 id, uint256 amount) external;

    /**
     * @notice Processes the withdrawal of tokens to increase the maxExposure
     * @param asset The address of the asset
     * @param amount The amount of tokens
     */
    function processWithdrawal(address asset, uint256 amount) external;
}
