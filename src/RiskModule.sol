/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./utils/FixedPointMathLib.sol";

/**
 * @title Risk Module
 * @author Arcadia Finance
 * @notice The Risk Module manages the supported asset related risks, collateral factor, liquidity threshold
 * @dev No end-user should directly interact with the Risk Module
 */
contract RiskModule {
    using FixedPointMathLib for uint256;

    mapping(address => mapping(uint256 => uint16)) public collateralFactors;
    mapping(address => mapping(uint256 => uint16)) public liquidationThresholds;

    uint16 public constant VARIABLE_DECIMAL = 100;

    uint16 public constant MIN_COLLATERAL_FACTOR = 0;
    uint16 public constant MIN_LIQUIDATION_THRESHOLD = 100;

    uint16 public constant MAX_COLLATERAL_FACTOR = 100;
    uint16 public constant MAX_LIQUIDATION_THRESHOLD = 10000;

    uint16 public constant DEFAULT_COLLATERAL_FACTOR = 50;
    uint16 public constant DEFAULT_LIQUIDATION_THRESHOLD = 110;

    /**
     * @notice Calculate the weighted collateral value given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @return collateralValue is the weighted collateral value of the given assets
     */
    function calculateWeightedCollateralValue(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset,
        uint256 baseCurrencyInd
    ) public view returns (uint256 collateralValue) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CCV: LENGTH_MISMATCH");
        for (uint256 i; i < assetAddressesLength;) {
            collateralValue += valuesPerAsset[i] * uint256(collateralFactors[assetAddresses[i]][baseCurrencyInd]);
            unchecked {
                ++i;
            }
        }
        collateralValue = collateralValue / VARIABLE_DECIMAL;
    }

    /**
     * @notice Calculate the weighted liquidation threshold given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @return liquidationThreshold is the weighted liquidation threshold of the given assets
     */
    function calculateWeightedLiquidationThreshold(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset,
        uint256 baseCurrencyInd
    ) public view returns (uint16 liquidationThreshold) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWLT: LENGTH_MISMATCH");

        uint256 liquidationThreshold256;
        uint256 totalValue;

        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            liquidationThreshold256 +=
                valuesPerAsset[i] * uint256(liquidationThresholds[assetAddresses[i]][baseCurrencyInd]);
            unchecked {
                i++;
            }
        }
        require(totalValue > 0, "RM_CWLT: Total asset value must be bigger than zero");
        // Not possible to overflow
        // given total_value = value_x + value_y + ... + value_n
        // liquidationThreshold = (liqThres_x * value_x + liqThres_y * value_y + ... + liqThres_n * value_n) / total_value
        // so liquidationThreshold will be in line with the liqThres_x, ... , liqThres_n
        unchecked {
            liquidationThreshold = uint16(liquidationThreshold256 / totalValue);
        }
    }
}
