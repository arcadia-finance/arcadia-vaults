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

    function addAsset(address assetAddress) external onlyOwner{
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

    function getCollateralFactor(address assetAddress) external returns (uint128) {
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

}
