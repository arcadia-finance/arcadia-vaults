/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { RiskConstants } from "./utils/RiskConstants.sol";

/**
 * @title Risk Module
 * @author Pragma Labs
 * @notice The Risk Module is responsible for calculating the risk weighted values of combinations of assets.
 */
library RiskModule {
    // Struct with risk related information for a certain asset.
    struct AssetValueAndRiskVariables {
        uint256 valueInBaseCurrency; // The value of the asset, denominated in a certain baseCurrency.
        uint256 collateralFactor; // The collateral factor of the asset for the given baseCurrency.
        uint256 liquidationFactor; // The liquidation factor of the asset for the given baseCurrency.
    }

    /**
     * @notice Calculates the weighted collateral value given a combination of asset values and corresponding collateral factors.
     * @param valuesAndRiskVarPerAsset Array of asset values and corresponding collateral factors.
     * @return collateralValue The collateral value of the given assets.
     */
    function calculateCollateralValue(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint256 collateralValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            collateralValue +=
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].collateralFactor;
            unchecked {
                ++i;
            }
        }
        collateralValue = collateralValue / RiskConstants.RISK_VARIABLES_UNIT;
    }

    /**
     * @notice Calculates the weighted liquidation value given a combination of asset values and corresponding liquidation factors.
     * @param valuesAndRiskVarPerAsset List of asset values and corresponding liquidation factors.
     * @return liquidationValue The liquidation value of the given assets.
     */
    function calculateLiquidationValue(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint256 liquidationValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            liquidationValue +=
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].liquidationFactor;
            unchecked {
                ++i;
            }
        }
        liquidationValue = liquidationValue / RiskConstants.RISK_VARIABLES_UNIT;
    }
}
