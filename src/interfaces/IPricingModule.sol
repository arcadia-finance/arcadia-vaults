/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IPricingModule {
    // A Struct with the input variables for the function getValue() (avoid stack to deep).
    struct GetValueInput {
        address asset; // The contract address of the asset.
        uint256 assetId; // The Id of the asset.
        uint256 assetAmount; // The amount of assets.
        uint256 baseCurrency; // Identifier of the BaseCurrency in which the value is ideally denominated.
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency.
     * @param input A Struct with the input variables (avoid stack to deep).
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return valueInBaseCurrency The value of the asset denominated in a BaseCurrency different from USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     */
    function getValue(GetValueInput memory input) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns the risk variables of an asset.
     * @param asset The contract address of the asset.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, 2 decimals precision.
     */
    function getRiskVariables(address asset, uint256 baseCurrency) external view returns (uint16, uint16);

    /**
     * @notice Processes the deposit of an asset.
     * @param vault The contract address of the Vault where the asset is transferred to.
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDeposit(address vault, address asset, uint256 id, uint256 amount) external;

    /**
     * @notice Processes the withdrawal an asset.
     * @param vault The address of the vault where the asset is withdrawn from
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processWithdrawal(address vault, address asset, uint256 id, uint256 amount) external;
}
