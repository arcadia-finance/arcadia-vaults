/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";
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
        uint224 valueInBaseCurrency;
        uint16 collateralFactor;
        uint16 liquidationFactor;
    }

    /**
     * @notice Calculate the weighted collateral value given a combination of asset values and corresponding collateral factors.
     * @param valuesAndRiskVarPerAsset List of asset values and corresponding collateral factors.
     * @return collateralValue The collateral value of the given assets
     */
    function calculateCollateralValue(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint256 collateralValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            unchecked {
                collateralValue +=
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].collateralFactor;
                ++i;
            }
        }
        collateralValue = collateralValue / RiskConstants.RISK_VARIABLES_UNIT;
    }

    /**
     * @notice Calculate the weighted liquidation value given a combination of asset values and corresponding liquidation factors.
     * @param valuesAndRiskVarPerAsset List of asset values and corresponding liquidation factors.
     * @return liquidationValue The value of a combination of assets, each discounted with a liquidation factor
     */
    function calculateLiquidationValue(AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset)
        public
        pure
        returns (uint256 liquidationValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            unchecked {
                liquidationValue +=
                    valuesAndRiskVarPerAsset[i].valueInBaseCurrency * valuesAndRiskVarPerAsset[i].liquidationFactor;
                ++i;
            }
        }
        liquidationValue = liquidationValue / RiskConstants.RISK_VARIABLES_UNIT;
    }
}
