/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../RiskModule.sol";
import "../../utils/FixedPointMathLib.sol";

contract RiskModuleTest is Test {
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;

    address public creator = address(1);
    address public nonCreator = address(2);

    RiskModule public riskModule;

    constructor() {
        vm.startPrank(creator);
        riskModule = new RiskModule();
        vm.stopPrank();
    }

    function testCalculateWeightedLiquidationThresholdSuccess(
        address firstAsset,
        address secondAsset,
        uint240 firstValue,
        uint240 secondValue
    ) public {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success
        // Values are uint240 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: The liquidation threshold is calculated with given values
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);

        // Then: The liquidation threshold has to be bigger than zero
        assertTrue(liqThres > 0);
    }

    function testCalculateWeightedLiquidationThresholdFail(address firstAsset, address secondAsset) public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the liquidation threshold should fail since the total value can't be zero
        vm.expectRevert("RM_CWLT: Total asset value must be bigger than zero");
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testCalculateWeightedLiquidationThresholdFailArithmetic(
        address firstAsset,
        address secondAsset,
        uint8 firstValueShift,
        uint8 secondValueShift
    ) public {
        // Given: The address of assets and the values of assets.
        // The values of assets should be so big to trigger arithmetic
        uint256 min_val = type(uint256).max / 3;
        uint256 firstValue = min_val + firstValueShift;
        uint256 secondValue = min_val + secondValueShift;
        uint256 max_val = type(uint256).max;
        vm.assume(firstValue < (max_val / 2));
        vm.assume(secondValue < (max_val / 2));

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the liquidation threshold should fail and reverted since liquidation calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testCalculateWeightedCollateralFactorSuccess(
        address firstAsset,
        address secondAsset,
        uint240 firstValue,
        uint240 secondValue
    ) public {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success.
        // Values are uint240 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: The collateral factor is calculated with given values
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);

        // Then: The collateral factor has to be bigger than zero
        assertTrue(collFactor > 0);
    }

    function testCalculateWeightedCollateralFactorFail(address firstAsset, address secondAsset) public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail since the total value can't be zero
        vm.expectRevert("RM_CWCF: Total asset value must be bigger than zero");
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }

    function testCalculateWeightedCollateralFactorFailArithmetic(
        address firstAsset,
        address secondAsset,
        uint8 firstValueShift,
        uint8 secondValueShift
    ) public {
        // Given: The address of assets and the values of assets.
        // The values of assets should be so big to trigger arithmetic
        uint256 min_val = type(uint256).max / 3;
        uint256 firstValue = min_val + firstValueShift;
        uint256 secondValue = min_val + secondValueShift;
        uint256 max_val = type(uint256).max;
        vm.assume(firstValue < (max_val / 2));
        vm.assume(secondValue < (max_val / 2));

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        uint16 liqThres = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }
}
