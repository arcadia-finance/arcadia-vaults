/**
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";
import "./libraries/AssetConfiguration.sol";

/**
 * @title Risk Module
 * @author Arcadia Finance
 * @notice The Risk Module manages the supported asset related risks, collateral factor, liquidity threshold
 * @dev No end-user should directly interact with the Risk Module
 */
contract RiskModule is Ownable {

    // TODO: This can be precalculated as bitmap
    AssetConfiguration.AssetDetail defaultConfig = AssetConfiguration.AssetDetail(
    {
    collateralFactor : uint16(2000),
    liquidityThreshold : uint16(3000),
    liquidityReward : uint16(500),
    protocolLiquidityFee : uint16(100),
    decimals : uint8(16),
    isActive : true,
    isFrozen : false,
    isPaused : false,
    isBorrowing : false
    });

    mapping(address => AssetConfiguration.AssetDetailBitmap) public assetConfigurationDetails;

    function addAsset(address assetAddress) external onlyOwner {
        require(!(assetConfigurationDetails[assetAddress].data > 0), "RM: Asset is already added");
        AssetConfiguration.AssetDetailBitmap memory config = AssetConfiguration.toBitmap(defaultConfig);
        assetConfigurationDetails[assetAddress] = config;
    }

    function addAsset(address assetAddress, AssetConfiguration.AssetDetail memory assetDetail) external onlyOwner {
        require(!(assetConfigurationDetails[assetAddress].data > 0), "RM: Asset is already added");
        AssetConfiguration.AssetDetailBitmap memory config = AssetConfiguration.toBitmap(assetDetail);
        assetConfigurationDetails[assetAddress] = config;
    }

    function setCollateralFactor(address assetAddress, uint16 collateralFactor) external onlyOwner {
        AssetConfiguration.AssetDetailBitmap memory config = assetConfigurationDetails[assetAddress];
        AssetConfiguration.setCollateralFactor(config, collateralFactor);
        assetConfigurationDetails[assetAddress] = config;
    }

    function getCollateralFactorHARDCODED(address assetAddress) public view returns (uint128) {
        return 150;
    }

    function getCollateralFactor(address assetAddress) public view returns (uint128) {
        return AssetConfiguration.getCollateralFactor(assetConfigurationDetails[assetAddress]);
    }

    function setLiquidationThreshold(address assetAddress, uint16 liquidationThreshold) external onlyOwner {
        AssetConfiguration.AssetDetailBitmap memory config = assetConfigurationDetails[assetAddress];
        AssetConfiguration.setLiquidationThreshold(config, liquidationThreshold);
        assetConfigurationDetails[assetAddress] = config;
    }

    function getLiquidationThreshold(address assetAddress) external returns (uint128) {
        return AssetConfiguration.getLiquidationThreshold(assetConfigurationDetails[assetAddress]);
    }

    function calculateMinCollateralFactor(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public returns (uint256) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == assetIds.length &&
            assetAddressesLength == assetAmounts.length,
            "RM_CMCF: LENGTH_MISMATCH"
        );
        uint minCollateralFactor = type(uint128).max;
        for (uint256 i; i < assetAddressesLength;) {
            address assetAddress = assetAddresses[i];
            uint128 collFact = getCollateralFactorHARDCODED(assetAddress);
            if (collFact < minCollateralFactor) {
                minCollateralFactor = collFact;
            }
        }
        return minCollateralFactor;
    }

    function calculateWeightedCollateralValue(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset
    ) public view returns (uint256) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == valuesPerAsset.length,
            "RM_CCV: LENGTH_MISMATCH"
        );
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

    function calculateWeightedCollateralFactor(
        address[] calldata assetAddresses,
        uint256[] memory valuesPerAsset
    ) public view returns (uint256) {
        uint256 assetAddressesLength = assetAddresses.length;
        require(
            assetAddressesLength == valuesPerAsset.length,
            "RM_CWCF: LENGTH_MISMATCH"
        );
        uint256 collateralFactor;
        uint256 totalValue;

        for (uint256 i; i < valuesPerAsset.length;){
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

}
