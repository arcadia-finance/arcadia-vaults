/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./utils/FixedPointMathLib.sol";
import {RiskConstants} from "./utils/RiskConstants.sol";

/**
 * @title Risk Module
 * @author Arcadia Finance
 * @notice The Risk Module manages the supported asset related risks, collateral factor, liquidity threshold
 * @dev No end-user should directly interact with the Risk Module
 */
library RiskModule {
    using FixedPointMathLib for uint256;

    struct AssetValueAndRiskVariables {
        uint256 valueInBaseCurrency;
        uint256 collFactor;
        uint256 liqThreshold;
    }

    struct AssetRisk {
        address asset;
        uint16[] assetCollateralFactors;
        uint16[] assetLiquidationThresholds;
    }

    /**
     * @notice Calculate the weighted collateral value given the assets
     * @param valuesAndRiskVarPerAsset The list of corresponding monetary values of each asset address.
     * @return collateralValue The collateral value of the given assets
     */
    function calculateWeightedCollateralValue(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint256 collateralValue)
    {
        for (uint256 i; i < valuesAndRiskVarPerAsset.length;) {
            collateralValue += valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].collFactor;
            unchecked {
                ++i;
            }
        }
        collateralValue = collateralValue / RiskConstants.RISK_VARIABLES_UNIT;
    }

    /**
     * @notice Calculate the weighted liquidation threshold given the assets
     * @param valuesAndRiskVarPerAsset The list of corresponding monetary values of each asset address.
     * @return liquidationThreshold is the weighted liquidation threshold of the given assets
     */
    function calculateWeightedLiquidationThreshold(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint16 liquidationThreshold)
    {
        uint256 liquidationThreshold256;
        uint256 totalValue;
        for (uint256 i; i < valuesAndRiskVarPerAsset.length;) {
            totalValue += valuesAndRiskVarPerAsset[i].valueInBaseCurrency;
            liquidationThreshold256 +=
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].liqThreshold;
            unchecked {
                ++i;
            }
        }
        require(totalValue > 0, "RM_CWLT: DIVIDE_BY_ZERO");
        // Not possible to overflow
        // given total_value = value_x + value_y + ... + value_n
        // liquidationThreshold = (liqThres_x * value_x + liqThres_y * value_y + ... + liqThres_n * value_n) / total_value
        // so liquidationThreshold will be in line with the liqThres_x, ... , liqThres_n
        unchecked {
            liquidationThreshold = uint16(liquidationThreshold256 / totalValue);
        }
    }

    /**
     * @notice Calculates the collateral value and weighted liquidation threshold given the assets
     * @param valuesAndRiskVarPerAsset A list of structs with the values and risk variables of each asset address:
     * - valueInBaseCurrency: The value of the asset denominated in baseCurrency with 18 decimals precision
     * - collFactor: The Collateral factor or haircut of the asset, to discount the MTM value, 2 decimals precision
     * - liqThreshold: The Liquidation Threshhold of the asset, 2 decimals precision
     * @return collateralValue The collateral value of the given assets
     * @return liquidationThreshold The weighted liquidation threshold of the given assets
     */
    function calculateCollateralValueAndLiquidationThreshold(
        AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset
    ) public pure returns (uint256 collateralValue, uint256 liquidationThreshold) {
        uint256 totalValue;
        for (uint256 i; i < valuesAndRiskVarPerAsset.length;) {
            totalValue += valuesAndRiskVarPerAsset[i].valueInBaseCurrency;

            collateralValue += valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].collFactor;

            liquidationThreshold +=
                valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].liqThreshold;
            unchecked {
                ++i;
            }
        }
        require(totalValue > 0, "RM_CCFALT: DIVIDE_BY_ZERO");

        unchecked {
            collateralValue = collateralValue / RiskConstants.RISK_VARIABLES_UNIT;
            liquidationThreshold = liquidationThreshold / totalValue;
        }
    }
}
