/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Risk Module
 * @author Arcadia Finance
 * @notice The Risk Module manages the supported asset related risks, collateral factor, liquidity threshold
 * @dev No end-user should directly interact with the Risk Module
 */
contract RiskModule is Ownable {
    function getCollateralFactorHARDCODED(address assetAddress) public view returns (uint128) {
        return 150;
    }

    function getLiquidationThresholdHARDCODED(address assetAddress) public view returns (uint16) {
        return 110;
    }

    function calculateMinCollateralFactor(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    )
        public
        returns (uint256)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length,
            "RM_CMCF: LENGTH_MISMATCH"
        );
        uint256 minCollateralFactor = type(uint128).max;
        for (uint256 i; i < assetAddressesLength;) {
            address assetAddress = assetAddresses[i];
            uint128 collFact = getCollateralFactorHARDCODED(assetAddress);
            if (collFact < minCollateralFactor) {
                minCollateralFactor = collFact;
            }
        }
        return minCollateralFactor;
    }

    function calculateWeightedCollateralValue(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint256)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CCV: LENGTH_MISMATCH");
        uint256 collateralValue;
        address assetAddress;
        uint256 collFact;
        for (uint256 i; i < assetAddressesLength;) {
            assetAddress = assetAddresses[i];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            collateralValue += valuesPerAsset[i] * 100 / collFact;
            unchecked {
                ++i;
            }
        }
        return collateralValue;
    }

    function calculateWeightedCollateralFactor(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint256)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWCF: LENGTH_MISMATCH");
        uint256 collateralFactor;
        uint256 totalValue;

        for (uint256 i; i < valuesPerAsset.length;) {
            totalValue += valuesPerAsset[i];
            unchecked {
                i++;
            }
        }
        uint128 collFact;
        for (uint256 j; j < assetAddressesLength;) {
            address assetAddress = assetAddresses[j];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            collateralFactor += collFact * (valuesPerAsset[j] / totalValue);
            unchecked {
                j++;
            }
        }
        return collateralFactor;
    }

    function calculateWeightedLiquidationThreshold(address[] calldata assetAddresses, uint256[] memory valuesPerAsset)
        public
        view
        returns (uint16)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWLT: LENGTH_MISMATCH");
        uint256 liquidationThreshold;
        uint256 totalValue;

        for (uint256 i; i < valuesPerAsset.length;) {
            totalValue += valuesPerAsset[i];
            unchecked {
                i++;
            }
        }
        uint16 liqThreshold;
        for (uint256 j; j < assetAddressesLength;) {
            address assetAddress = assetAddresses[j];
            liqThreshold = getLiquidationThresholdHARDCODED(assetAddress);
            liquidationThreshold += uint256(liqThreshold) * valuesPerAsset[j] / totalValue;
            unchecked {
                j++;
            }
        }
        return uint16(liquidationThreshold);
    }

    function calculateWeightedLiquidationValue(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset,
        uint256 debt
    )
        public
        view
        returns (uint256)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CCV: LENGTH_MISMATCH");
        uint256 liquidationThreshold = calculateWeightedLiquidationThreshold(assetAddresses, valuesPerAsset);
        return liquidationThreshold * debt;
    }
}
