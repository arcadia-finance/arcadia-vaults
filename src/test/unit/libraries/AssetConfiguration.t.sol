/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../../../lib/forge-std/src/Test.sol";
import "../../../libraries/AssetConfiguration.sol";


contract AssetConfigurationTest is Test {
    using stdStorage for StdStorage;

    function testValidCollateralFactor() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The collateral factor is fetch from the config
        uint256 collateralFactor1 = AssetConfiguration.getCollateralFactor(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(collateralFactor1, 0);

        // Then Given: The collateral ratio is set as 1
        AssetConfiguration.setCollateralFactor(initialConfig, uint128(1));

        // When: The collateral factor is fetched
        uint256 collateralFactor2 = AssetConfiguration.getCollateralFactor(initialConfig);

        // Then: New collateral factor should be 1 not 0
        assertEq(collateralFactor2, 1);
        assertTrue(collateralFactor2 != 0);
    }

    function testInvalidCollateralFactor() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When Then: The collateral factor is set with invalid value, it should revert
        vm.expectRevert("Invalid Collateral Factor parameter for asset");
        AssetConfiguration.setCollateralFactor(initialConfig, 65537);

    }

    function testValidLiquidationThreshold() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The liquidity threshold is fetch from the config
        uint256 liquidationThreshold1 = AssetConfiguration.getLiquidationThreshold(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(liquidationThreshold1, 0);

        // Then Given: The liquidity threshold is set as 1
        AssetConfiguration.setLiquidationThreshold(initialConfig, uint128(1));

        // When: The liquidity threshold is fetched
        uint256 liquidationThreshold2 = AssetConfiguration.getLiquidationThreshold(initialConfig);

        // Then: New liquidity threshold factor should be 1 not 0
        assertEq(liquidationThreshold2, 1);
        assertTrue(liquidationThreshold2 != 0);
    }

    function testInvalidLiquidationThreshold() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When Then: The liquidity threshold is set with invalid value, it should revert
        vm.expectRevert("Invalid Liquidity Threshold parameter for asset");
        AssetConfiguration.setLiquidationThreshold(initialConfig, 65537);

    }

    function testValidLiquidationReward() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The liquidity reward is fetch from the config
        uint256 liquidationReward1 = AssetConfiguration.getLiquidationReward(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(liquidationReward1, 0);

        // Then Given: The liquidity reward is set as 10
        AssetConfiguration.setLiquidationReward(initialConfig, 10);

        // When: The liquidity reward is fetched
        uint256 liquidationReward2 = AssetConfiguration.getLiquidationReward(initialConfig);

        // Then: New liquidity reward factor should be 10 not 0
        assertEq(liquidationReward2, 10);
        assertTrue(liquidationReward2 != 0);
    }

    function testInvalidLiquidationReward() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When Then: The collateral factor is set with invalid value, it should revert
        vm.expectRevert("Invalid Liquidity Reward parameter for asset");
        AssetConfiguration.setLiquidationReward(initialConfig, 65537);

    }

    function testValidProtocolLiquidationFee() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The protocol liquidity fee is fetch from the config
        uint256 liquidationFee1 = AssetConfiguration.getProtocolLiquidationFee(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(liquidationFee1, 0);

        // Then Given: The protocol liquidity fee is set as 110
        AssetConfiguration.setProtocolLiquidationFee(initialConfig, 110);

        // When: The protocol liquidity fee is fetched
        uint256 liquidationFee2 = AssetConfiguration.getProtocolLiquidationFee(initialConfig);

        // Then: New protocol liquidity fee should be 110 not 0
        assertEq(liquidationFee2, 110);
        assertTrue(liquidationFee2 != 0);
    }

    function testInvalidProtocolLiquidationFee() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When Then: The protocol liquidity fee is set with invalid value, it should revert
        vm.expectRevert("Invalid Protocol Liquidity Fee parameter for asset");
        AssetConfiguration.setProtocolLiquidationFee(initialConfig, 65537);

    }

    function testValidDecimals() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The decimals is fetch from the config
        uint256 decimals1 = AssetConfiguration.getDecimals(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(decimals1, 0);

        // Then Given: The decimal is set as 16
        AssetConfiguration.setDecimals(initialConfig, 16);

        // When: The decimals is fetched
        uint256 decimals2 = AssetConfiguration.getDecimals(initialConfig);

        // Then: New decimals should be 16 not 0
        assertEq(decimals2, 16);
        assertTrue(decimals2 != 0);
    }

    function testInvalidDecimals() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When Then: The decimals is set with invalid value, it should revert
        vm.expectRevert("Invalid Decimal for asset");
        AssetConfiguration.setDecimals(initialConfig, 256);

    }

    function testValidIsActive() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The active is fetch from the config
        bool isActive1 = AssetConfiguration.getActive(initialConfig);

        // Then: It should be false, because it is not set (0 == False).
        assertTrue(isActive1 == false);

        // Then Given: The active is set as True ( 1 == True)
        AssetConfiguration.setActive(initialConfig, true);

        // When: The active is fetched
        bool isActive2 = AssetConfiguration.getActive(initialConfig);

        // Then: New active should be True not False
        assertTrue(isActive2);
        assertTrue(isActive2 != false);
    }

    function testValidIsFrozen() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The frozen is fetch from the config
        bool isFrozen1 = AssetConfiguration.getFrozen(initialConfig);

        // Then: It should be false, because it is not set (0 == False).
        assertTrue(isFrozen1 == false);

        // Then Given: The frozen is set as True ( 1 == True)
        AssetConfiguration.setFrozen(initialConfig, true);

        // When: The frozen is fetched
        bool isFrozen2 = AssetConfiguration.getFrozen(initialConfig);

        // Then: New frozen should be True not False
        assertTrue(isFrozen2);
        assertTrue(isFrozen2 != false);
    }

    function testValidIsPaused() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The paused is fetch from the config
        bool isPaused1 = AssetConfiguration.getPaused(initialConfig);

        // Then: It should be false, because it is not set (0 == False).
        assertTrue(isPaused1 == false);

        // Then Given: The paused is set as True ( 1 == True)
        AssetConfiguration.setPaused(initialConfig, true);

        // When: The paused is fetched
        bool isPaused2 = AssetConfiguration.getPaused(initialConfig);

        // Then: New paused should be True not False
        assertTrue(isPaused2);
        assertTrue(isPaused2 != false);
    }

    function testValidIsBorrowing() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The borrowing is fetch from the config
        bool isBorrowing1 = AssetConfiguration.getBorrowing(initialConfig);

        // Then: It should be false, because it is not set (0 == False).
        assertTrue(isBorrowing1 == false);

        // Then Given: The borrowing is set as True ( 1 == True)
        AssetConfiguration.setBorrowing(initialConfig, true);

        // When: The borrowing is fetched
        bool isBorrowing2 = AssetConfiguration.getBorrowing(initialConfig);

        // Then: New borrowing should be True not False
        assertTrue(isBorrowing2);
        assertTrue(isBorrowing2 != false);
    }
}
