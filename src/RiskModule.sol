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
    // TODO: To be deleted after the asset specific values are implemented
    function getCollateralFactorHARDCODED(address assetAddress) public view returns (uint128) {
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
    )
        public
        returns (uint256 minCollateralFactor)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length,
            "RM_CMCF: LENGTH_MISMATCH"
        );
        minCollateralFactor = type(uint128).max;
        for (uint256 i; i < assetAddressesLength;) {
            address assetAddress = assetAddresses[i];
            uint128 collFact = getCollateralFactorHARDCODED(assetAddress);
            if (collFact < minCollateralFactor) {
                minCollateralFactor = collFact;
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
            collateralValue += valuesPerAsset[i] * 100 / collFact;
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
        returns (uint256 collateralFactor)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWCF: LENGTH_MISMATCH");
        uint256 totalValue;

        uint128 collFact;
        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            address assetAddress = assetAddresses[i];
            collFact = getCollateralFactorHARDCODED(assetAddress);
            collateralFactor += collFact * valuesPerAsset[i];
            unchecked {
                i++;
            }
        }
        collateralFactor = collateralFactor / totalValue;
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
        returns (uint16)
    {
        uint256 assetAddressesLength = assetAddresses.length;
        require(assetAddressesLength == valuesPerAsset.length, "RM_CWLT: LENGTH_MISMATCH");
        uint256 liquidationThreshold;
        uint256 totalValue;

        uint16 liqThreshold;
        for (uint256 i; i < assetAddressesLength;) {
            totalValue += valuesPerAsset[i];
            address assetAddress = assetAddresses[i];
            liqThreshold = getLiquidationThresholdHARDCODED(assetAddress);
            liquidationThreshold += uint256(liqThreshold) * valuesPerAsset[i];
            unchecked {
                i++;
            }
        }
        liquidationThreshold = liquidationThreshold / totalValue;
        return uint16(liquidationThreshold);
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
