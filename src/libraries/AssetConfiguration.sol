/**
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

/**
 * @title AssetConfiguration library
 * @author Arcadia Finance
 * @notice Implements the bitmap logic to handle the asset configurations
 */
library AssetConfiguration {

    struct AssetDetailBitmap {
        // BITMAP
        //16 bit (0-15)  : Collateral Ratio
        //16 bit (16-31) : Liquidity Threshold
        //16 bit (32-47) : Liquidity reward
        //16 bit (48-63) : Protocol liquidation fee
        //8  bit (64-71) : Decimals
        //1  bit (72)    : Asset is active
        //1  bit (73)    : Asset is frozen
        //1  bit (74)    : Asset is paused
        //1  bit (75)    : Asset borrowing is enabled
        //52 bit (76-127): Unused
        uint128 data;
    }


    uint128 internal constant COLLATERAL_FACTOR_MASK =         0x7FFFFFFFFFFFFFFFFFFFFFFFFFFF0000;
    uint128 internal constant LIQUIDATION_THRESHOLD_MASK =     0x7FFFFFFFFFFFFFFFFFFFFFFF0000FFFF;
    uint128 internal constant LIQUIDATION_REWARD_MASK =        0x7FFFFFFFFFFFFFFFFFFF0000FFFFFFFF;
    uint128 internal constant PROTOCOL_LIQUIDATION_FEE_MASK =  0x7FFFFFFFFFFFFFFF0000FFFFFFFFFFFF;
    uint128 internal constant DECIMALS_MASK =                  0x7FFFFFFFFFFFFF00FFFFFFFFFFFFFFFF;
    uint128 internal constant ACTIVE_MASK =                    0x7FFFFFFFFFFFFEFFFFFFFFFFFFFFFFFF;
    uint128 internal constant FROZEN_MASK =                    0x7FFFFFFFFFFFFDFFFFFFFFFFFFFFFFFF;
    uint128 internal constant PAUSED_MASK =                    0x7FFFFFFFFFFFFBFFFFFFFFFFFFFFFFFF;
    uint128 internal constant BORROWING_MASK =                 0x7FFFFFFFFFFFF7FFFFFFFFFFFFFFFFFF;

    uint128 internal constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint128 internal constant LIQUIDATION_REWARD_START_BIT_POSITION = 32;
    uint128 internal constant PROTOCOL_LIQUIDATION_FEE_START_BIT_POSITION = 48;
    uint128 internal constant ASSET_DECIMALS_START_BIT_POSITION = 64;
    uint128 internal constant IS_ACTIVE_START_BIT_POSITION = 72;
    uint128 internal constant IS_FROZEN_START_BIT_POSITION = 73;
    uint128 internal constant IS_PAUSED_START_BIT_POSITION = 74;
    uint128 internal constant IS_BORROWING_ENABLED_START_BIT_POSITION = 75;

    uint128 internal constant MAX_VALID_COLLATERAL_FACTOR = 65535;
    uint128 internal constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
    uint128 internal constant MAX_VALID_LIQUIDATION_REWARD = 65535;
    uint128 internal constant MAX_VALID_PROTOCOL_LIQUIDATION_FEE = 65535;
    uint128 internal constant MAX_VALID_DECIMALS = 255;

    /**
    * @notice Sets the Collateral Factor of the asset
    * @param assetDetail The asset configuration
    * @param factor The new collateral factor
    **/
    function setCollateralFactor(AssetDetailBitmap memory assetDetail, uint128 factor) internal pure {
        require(factor <= MAX_VALID_COLLATERAL_FACTOR, 'Invalid Collateral Factor parameter for asset');

        assetDetail.data = (assetDetail.data & COLLATERAL_FACTOR_MASK) | factor;
    }

    /**
    * @notice Gets the Collateral Factor of the asset
    * @param assetDetail The a configuration
    * @return The collateral factor
    **/
    function getCollateralFactor(AssetDetailBitmap memory assetDetail) internal pure returns (uint128) {
        return assetDetail.data & ~COLLATERAL_FACTOR_MASK;
    }

    /**
    * @notice Sets the liquidation threshold of the asset
    * @param assetDetail The asset configuration
    * @param threshold The new liquidation threshold
    **/
    function setLiquidationThreshold(AssetDetailBitmap memory assetDetail, uint128 threshold) internal pure {
        require(threshold <= MAX_VALID_LIQUIDATION_THRESHOLD, 'Invalid Liquidity Threshold parameter for asset');

        assetDetail.data =
        (assetDetail.data & LIQUIDATION_THRESHOLD_MASK) |
        (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
    }

    /**
    * @notice Gets the liquidation threshold of the asset
    * @param assetDetail The asset configuration
    * @return The liquidation threshold
    **/
    function getLiquidationThreshold(AssetDetailBitmap memory assetDetail) internal pure returns (uint128)
    {
        return (assetDetail.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
    * @notice Sets the liquidation reward of the asset
    * @param assetDetail The asset configuration
    * @param reward The new liquidation reward
    **/
    function setLiquidationReward(AssetDetailBitmap memory assetDetail, uint128 reward) internal pure {
        require(reward <= MAX_VALID_LIQUIDATION_REWARD, 'Invalid Liquidity Reward parameter for asset');

        assetDetail.data =
        (assetDetail.data & LIQUIDATION_REWARD_MASK) |
        (reward << LIQUIDATION_REWARD_START_BIT_POSITION);
    }

    /**
    * @notice Gets the liquidation reward of the asset
    * @param assetDetail The asset configuration
    * @return The liquidation reward
    **/
    function getLiquidationReward(AssetDetailBitmap memory assetDetail) internal pure returns (uint128)
    {
        return (assetDetail.data & ~LIQUIDATION_REWARD_MASK) >> LIQUIDATION_REWARD_START_BIT_POSITION;
    }

    /**
    * @notice Sets the liquidation reward of the asset
    * @param assetDetail The asset configuration
    * @param fee The new protocol liquidation fee
    **/
    function setProtocolLiquidationFee(AssetDetailBitmap memory assetDetail, uint128 fee) internal pure {
        require(fee <= MAX_VALID_PROTOCOL_LIQUIDATION_FEE, 'Invalid Protocol Liquidity Fee parameter for asset');

        assetDetail.data =
        (assetDetail.data & PROTOCOL_LIQUIDATION_FEE_MASK) |
        (fee << PROTOCOL_LIQUIDATION_FEE_START_BIT_POSITION);
    }

    /**
    * @notice Gets the protocol liquidation fee of the asset
    * @param assetDetail The asset configuration
    * @return The protocol liquidation fee
    **/
    function getProtocolLiquidationFee(AssetDetailBitmap memory assetDetail) internal pure returns (uint128)
    {
        return (assetDetail.data & ~PROTOCOL_LIQUIDATION_FEE_MASK) >> PROTOCOL_LIQUIDATION_FEE_START_BIT_POSITION;
    }

    /**
    * @notice Sets the decimals of the underlying asset of the reserve
    * @param assetDetail The reserve configuration
    * @param decimals The decimals
    **/
    function setDecimals(AssetDetailBitmap memory assetDetail, uint128 decimals) internal pure
    {
        require(decimals <= MAX_VALID_DECIMALS, 'Invalid Decimal for asset');

        assetDetail.data = (assetDetail.data & DECIMALS_MASK) | (decimals << ASSET_DECIMALS_START_BIT_POSITION);
    }

    /**
    * @notice Gets the decimals of the underlying asset of the reserve
    * @param assetDetail The reserve configuration
    * @return The decimals of the asset
    **/
    function getDecimals(AssetDetailBitmap memory assetDetail) internal pure returns (uint128)
    {
        return (assetDetail.data & ~DECIMALS_MASK) >> ASSET_DECIMALS_START_BIT_POSITION;
    }

    /**
    * @notice Sets the active state of the asset
    * @param assetDetail The asset configuration
    * @param active The active state
    **/
    function setActive(AssetDetailBitmap memory assetDetail, bool active) internal pure {
        assetDetail.data =
        (assetDetail.data & ACTIVE_MASK) |
        (uint128(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
    }

    /**
    * @notice Gets the active state of the asset
    * @param assetDetail The asset configuration
    * @return The active state
    **/
    function getActive(AssetDetailBitmap memory assetDetail) internal pure returns (bool) {
        return (assetDetail.data & ~ACTIVE_MASK) != 0;
    }

    /**
    * @notice Sets the frozen state of the asset
    * @param assetDetail The asset configuration
    * @param frozen The frozen state
    **/
    function setFrozen(AssetDetailBitmap memory assetDetail, bool frozen) internal pure {
        assetDetail.data =
        (assetDetail.data & FROZEN_MASK) |
        (uint128(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
    }

    /**
    * @notice Gets the frozen state of the asset
    * @param assetDetail The asset configuration
    * @return The frozen state
    **/
    function getFrozen(AssetDetailBitmap memory assetDetail) internal pure returns (bool) {
        return (assetDetail.data & ~FROZEN_MASK) != 0;
    }

    /**
    * @notice Sets the paused state of the asset
    * @param assetDetail The asset configuration
    * @param paused The paused state
    **/
    function setPaused(AssetDetailBitmap memory assetDetail, bool paused) internal pure {
        assetDetail.data =
        (assetDetail.data & PAUSED_MASK) |
        (uint128(paused ? 1 : 0) << IS_PAUSED_START_BIT_POSITION);
    }

    /**
    * @notice Gets the paused state of the asset
    * @param assetDetail The asset configuration
    * @return The paused state
    **/
    function getPaused(AssetDetailBitmap memory assetDetail) internal pure returns (bool) {
        return (assetDetail.data & ~PAUSED_MASK) != 0;
    }

    /**
    * @notice Sets the borrowing state of the asset
    * @param assetDetail The asset configuration
    * @param borrowing The borrowing state
    **/
    function setBorrowing(AssetDetailBitmap memory assetDetail, bool borrowing) internal pure {
        assetDetail.data =
        (assetDetail.data & BORROWING_MASK  ) |
        (uint128(borrowing ? 1 : 0) << IS_BORROWING_ENABLED_START_BIT_POSITION);
    }

    /**
    * @notice Gets the active state of the asset
    * @dev If the returned flag is true, the asset is borrowable.
    * @param assetDetail The asset configuration
    * @return The borrowing state
    **/
    function getBorrowing(AssetDetailBitmap memory assetDetail) internal pure returns (bool) {
        return (assetDetail.data & ~BORROWING_MASK) != 0;
    }


}