/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./utils/FixedPointMathLib.sol";

/**
 * @title Risk Module
 * @author Arcadia Finance
 * @notice The Risk Module manages the supported asset related risks, collateral factor, liquidity threshold
 * @dev No end-user should directly interact with the Risk Module
 */
contract RiskModule is Ownable {
    using FixedPointMathLib for uint256;

    mapping(address => mapping(uint256 => uint16)) public collateralFactors;
    mapping(address => mapping(uint256 => uint16)) public liquidationThresholds;

    uint16 VARIABLE_DECIMAL = 100;

    uint16 MIN_COLLATERAL_FACTOR = 1;
    uint16 MIN_LIQUIDATION_THRESHOLD = 1;

    uint16 MAX_COLLATERAL_FACTOR = 10000;
    uint16 MAX_LIQUIDATION_THRESHOLD = 10000;

    uint16 DEFAULT_COLLATERAL_FACTOR = 150;
    uint16 DEFAULT_LIQUIDATION_THRESHOLD = 110;

    function getCollateralFactor(address assetAddress, uint256 baseCurrency) public view returns (uint16) {
        return collateralFactors[assetAddress][baseCurrency];
    }

    function getLiquidationThreshold(address assetAddress, uint256 baseCurrency) public view returns (uint16) {
        return liquidationThresholds[assetAddress][baseCurrency];
    }

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
        address assetAddress;
        uint256 collFact;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            collFact = getCollateralFactor(assetAddress, baseCurrencyInd);
            collateralValue += valuesPerAsset[i] * uint256(collFact);
            unchecked {
                ++i;
            }
        }
        return collateralValue / VARIABLE_DECIMAL;
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
        uint16 liqThreshold;
        address assetAddress;

        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            assetAddress = assetAddresses[i];
            liqThreshold = getLiquidationThreshold(assetAddress, baseCurrencyInd);
            liquidationThreshold256 += valuesPerAsset[i] * uint256(liqThreshold);
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
        return liquidationThreshold;
    }
}
