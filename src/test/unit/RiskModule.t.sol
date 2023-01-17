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

    function testSuccess_calculateCollateralFactor_Success(
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

        // And: collateral factors are within allowed ranges
        vm.assume(firstCollFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(secondCollFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        values[0].collateralFactor = firstCollFactor;
        values[1].collateralFactor = secondCollFactor;

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = RiskModule.calculateCollateralValue(values);

        // Then: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        for (uint256 i; i < values.length;) {
            calcCollateralValue += values[i].valueInBaseCurrency * values[i].collateralFactor;
            unchecked {
                ++i;
            }
        }

        calcCollateralValue = calcCollateralValue / 100;
        assertEq(collateralValue, calcCollateralValue);
    }

    function testSuccess_calculateLiquidationValue_Success(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstLiqFactor,
        uint16 secondLiqFactor
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidation factors are within allowed ranges
        vm.assume(firstLiqFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        vm.assume(secondLiqFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);

        values[0].liquidationFactor = firstLiqFactor;
        values[1].liquidationFactor = secondLiqFactor;

        // When: The Liquidation factor is calculated with given values
        uint256 liquidationValue = RiskModule.calculateLiquidationValue(values);

        // Then: It should be equal to calculated Liquidation factor
        uint256 calcLiquidationValue;
        for (uint256 i; i < values.length;) {
            calcLiquidationValue += values[i].valueInBaseCurrency * values[i].liquidationFactor;
            unchecked {
                ++i;
            }
        }

        calcLiquidationValue = calcLiquidationValue / 100;
        assertEq(liquidationValue, calcLiquidationValue);
    }
}
