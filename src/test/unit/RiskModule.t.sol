/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import {RiskModule} from "../../RiskModule.sol";
import {RiskConstants} from "../../utils/RiskConstants.sol";
import {FixedPointMathLib} from "../../utils/FixedPointMathLib.sol";

contract RiskModuleTest is Test {
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;

    constructor() {}

    function testSuccess_calculateWeightedCollateralFactor_Success(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstCollFactor,
        uint16 secondCollFactor
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidity Thresholds are within allowed ranges
        vm.assume(firstCollFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(secondCollFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        values[0].collFactor = firstCollFactor;
        values[1].collFactor = secondCollFactor;

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = RiskModule.calculateWeightedCollateralValue(values);

        // Then: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        for (uint256 i; i < values.length;) {
            calcCollateralValue += values[i].valueInBaseCurrency * values[i].collFactor;
            unchecked {
                ++i;
            }
        }

        calcCollateralValue = calcCollateralValue / 100;
        assertEq(collateralValue, calcCollateralValue);
    }

    function testRevert_calculateWeightedCollateralFactor_EvmAritmetic(uint8 firstValueShift, uint8 secondValueShift)
        public
    {
        // Given: The address of assets and the values of assets.
        // The values of assets should be so big to trigger arithmetic
        uint256 min_val = type(uint256).max / 3;
        uint256 firstValue = min_val + firstValueShift;
        uint256 secondValue = min_val + secondValueShift;
        uint256 max_val = type(uint256).max;
        vm.assume(firstValue < (max_val / 2));
        vm.assume(secondValue < (max_val / 2));

        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        values[0].collFactor = 150;
        values[1].collFactor = 150;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        RiskModule.calculateWeightedCollateralValue(values);
    }

    function testRevert_calculateWeightedLiquidationThreshold_ZeroTotalAssetValue() public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // When Then: Calculation of the liquidation threshold should fail since the total value can't be zero
        vm.expectRevert("RM_CWLT: DIVIDE_BY_ZERO");
        RiskModule.calculateWeightedLiquidationThreshold(values);
    }

    function testSuccess_calculateWeightedLiquidationThreshold_Success(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstLiqThreshold,
        uint16 secondLiqThreshold
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidity Thresholds are within allowed ranges
        vm.assume(
            firstLiqThreshold >= RiskConstants.MIN_LIQUIDATION_THRESHOLD
                || firstLiqThreshold <= RiskConstants.MAX_LIQUIDATION_THRESHOLD
        );
        vm.assume(
            secondLiqThreshold >= RiskConstants.MIN_LIQUIDATION_THRESHOLD
                || secondLiqThreshold <= RiskConstants.MAX_LIQUIDATION_THRESHOLD
        );

        values[0].liqThreshold = firstLiqThreshold;
        values[1].liqThreshold = secondLiqThreshold;

        // When: The liquidation threshold is calculated with given values
        uint16 liqThres = RiskModule.calculateWeightedLiquidationThreshold(values);

        // Then: The liquidation threshold should be equal to calculated liquidity threshold
        uint256 calcLiqThreshold;
        uint256 totalValue;
        for (uint256 i; i < values.length;) {
            totalValue += values[i].valueInBaseCurrency;
            calcLiqThreshold += values[i].valueInBaseCurrency * values[i].liqThreshold;
            unchecked {
                ++i;
            }
        }
        calcLiqThreshold = calcLiqThreshold / totalValue;

        assertEq(liqThres, calcLiqThreshold);
    }

    function testRevert_calculateWeightedLiquidationThreshold_arithmetic(uint8 firstValueShift, uint8 secondValueShift)
        public
    {
        // Given: The address of assets and the values of assets.
        // The values of assets should be so big to trigger arithmetic
        uint256 min_val = type(uint256).max / 3;
        uint256 firstValue = min_val + firstValueShift;
        uint256 secondValue = min_val + secondValueShift;
        uint256 max_val = type(uint256).max;
        vm.assume(firstValue < (max_val / 2));
        vm.assume(secondValue < (max_val / 2));

        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        values[0].liqThreshold = 110;
        values[1].liqThreshold = 110;

        // When Then: Calculation of the liquidation threshold should fail and reverted since liquidation calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        RiskModule.calculateWeightedLiquidationThreshold(values);
    }
}
