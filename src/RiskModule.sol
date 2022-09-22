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

    // TODO: To be deleted after the asset specific values are implemented
    function getCollateralFactorHARDCODED(address assetAddress) public view returns (uint16) {
        return 150;
    }

    // TODO: To be deleted after the asset specific values are implemented
    function getLiquidationThresholdHARDCODED(address assetAddress) public view returns (uint16) {
        return 110;
    }

    /**
     * @notice Calculate the minimum collateral factor given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param assetIds The list of corresponding token Ids that needs to be checked
     * @dev For each token address, a corresponding id at the same index should be present,
     * for tokens without Id (ERC20 for instance), the Id should be set to 0
     * @param assetAmounts The list of corresponding amounts of each Token-Id combination
     * @return minCollateralFactor is the minimum collateral factor of the given assets
     * @dev CAN BE DEPRECATED OR DELETED: Added here for possible later use, if in later stages it is not used delete.
     */
    function calculateMinCollateralFactor(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public returns (uint16 minCollateralFactor) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length,
            "RM_CMCF: LENGTH_MISMATCH"
        );
        minCollateralFactor = type(uint16).max;
        address assetAddress;
        uint16 collFact;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            if (collFact < minCollateralFactor) {
                minCollateralFactor = collFact;
            }
            unchecked {
                ++i;
            }
        }
        return minCollateralFactor;
    }

    /**
     * @notice Calculate the weighted collateral value given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @return collateralValue is the weighted collateral value of the given assets
     */
    function calculateWeightedCollateralValue(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint256 collateralValue)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CCV: LENGTH_MISMATCH");
        address assetAddress;
        uint256 collFact;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            collateralValue += valuesPerAsset[i].mulDivDown(100, uint256(collFact));
            unchecked {
                ++i;
            }
        }
        return collateralValue;
    }

    /**
     * @notice Calculate the weighted collateral factor given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @return collateralFactor is the weighted collateral factor of the given assets
     */
    function calculateWeightedCollateralFactor(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint16 collateralFactor)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWCF: LENGTH_MISMATCH");

        uint256 totalValue;
        uint256 collateralFactor256;
        uint16 collFact;
        address assetAddress;

        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            assetAddress = assetAddresses[i];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            collateralFactor256 += valuesPerAsset[i] * uint256(collFact);
            unchecked {
                i++;
            }
        }

        require(totalValue > 0, "RM_CWCF: Total asset value must be bigger than zero");
        // Not possible to overflow
        // given total_value = value_x + value_y + ... + value_n
        // collateralFactor = (colFact_x * value_x + colFact_y * value_y + ... + colFact_n * value_n) / total_value
        // so collateralFactor will be in line with the colFact_x, ... , colFact_n
        unchecked {
            collateralFactor = uint16(collateralFactor256 / totalValue);
        }
        return collateralFactor;
    }

    /**
     * @notice Calculate the weighted liquidation threshold given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @return liquidationThreshold is the weighted liquidation threshold of the given assets
     */
    function calculateWeightedLiquidationThreshold(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint16 liquidationThreshold)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWLT: LENGTH_MISMATCH");

        uint256 liquidationThreshold256;
        uint256 totalValue;
        uint16 liqThreshold;
        address assetAddress;

        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            assetAddress = assetAddresses[i];
            liqThreshold = getLiquidationThresholdHARDCODED(assetAddress);
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

    /**
     * @notice Calculate the weighted liquidation value given the assets
     * @param assetAddresses The List of token addresses of the assets
     * @param valuesPerAsset The list of corresponding monetary values of each asset address.
     * @param debt The value of the debt.
     * @return liquidation value is the weighted liquidation threshold of the given assets
     * @dev CAN BE DEPRECATED OR DELETED: Added here for possible later use, if in later stages it is not used delete.
     */
    function calculateWeightedLiquidationValue(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset,
        uint256 debt
    ) public view returns (uint256) {
        require(assetAddresses.length == valuesPerAsset.length, "RM_CCV: LENGTH_MISMATCH");
        uint256 liquidationThreshold = calculateWeightedLiquidationThreshold(assetAddresses, valuesPerAsset);
        return liquidationThreshold * debt;
    }
}
