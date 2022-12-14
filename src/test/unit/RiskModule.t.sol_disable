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

    address firstAssetAddress = address(98);
    address secondAssetAddress = address(99);

    constructor() {
        vm.startPrank(creator);
        riskModule = new RiskModule();

        // Set liquidation threshold
        stdstore.target(address(riskModule)).sig(riskModule.liquidationThresholds.selector).with_key(
            address(firstAssetAddress)
        ).with_key(uint256(0)).checked_write(110);
        stdstore.target(address(riskModule)).sig(riskModule.liquidationThresholds.selector).with_key(
            address(secondAssetAddress)
        ).with_key(uint256(0)).checked_write(110);

        // Set collateral factor
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(firstAssetAddress)
        ).with_key(uint256(0)).checked_write(50);
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(secondAssetAddress)
        ).with_key(uint256(0)).checked_write(50);

        vm.stopPrank();
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

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidity Thresholds are within allowed ranges
        vm.assume(
            firstLiqThreshold >= riskModule.MIN_LIQUIDATION_THRESHOLD()
                || firstLiqThreshold <= riskModule.MAX_LIQUIDATION_THRESHOLD()
        );
        vm.assume(
            secondLiqThreshold >= riskModule.MIN_LIQUIDATION_THRESHOLD()
                || secondLiqThreshold <= riskModule.MAX_LIQUIDATION_THRESHOLD()
        );

        uint256[] memory liquidationThresholds = new uint256[](2);
        liquidationThresholds[0] = firstLiqThreshold;
        liquidationThresholds[1] = secondLiqThreshold;

        stdstore.target(address(riskModule)).sig(riskModule.liquidationThresholds.selector).with_key(
            address(firstAssetAddress)
        ).with_key(uint256(0)).checked_write(firstLiqThreshold);
        stdstore.target(address(riskModule)).sig(riskModule.liquidationThresholds.selector).with_key(
            address(secondAssetAddress)
        ).with_key(uint256(0)).checked_write(secondLiqThreshold);

        // When: The liquidation threshold is calculated with given values
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);

        // Then: The liquidation threshold should be equal to calculated liquidity threshold
        uint256 calcLiqThreshold;
        uint16 calcLiqThres;
        uint256 totalValue;
        address assetAddress;

        for (uint256 i; i < addresses.length;) {
            totalValue += values[i].valueInBaseCurrency;
            assetAddress = addresses[i];
            calcLiqThres = riskModule.liquidationThresholds(assetAddress, 0);
            calcLiqThreshold += values[i].valueInBaseCurrency * liquidationThresholds[i];
            unchecked {
                ++i;
            }
        }
        calcLiqThreshold = calcLiqThreshold / totalValue;

        assertEq(liqThres, calcLiqThreshold);
    }

    function testRevert_calculateWeightedLiquidationThreshold_ZeroTotalAssetValue() public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = firstAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // When Then: Calculation of the liquidation threshold should fail since the total value can't be zero
        vm.expectRevert("RM_CWLT: Total asset value must be bigger than zero");
        riskModule.calculateWeightedLiquidationThreshold(addresses, values);
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

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // When Then: Calculation of the liquidation threshold should fail and reverted since liquidation calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testSuccess_calculateWeightedCollateralFactor_Success(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstCollFactor,
        uint16 secondCollFactor
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidity Thresholds are within allowed ranges
        vm.assume(
            firstCollFactor >= riskModule.MIN_COLLATERAL_FACTOR()
                || firstCollFactor <= riskModule.MAX_COLLATERAL_FACTOR()
        );
        vm.assume(
            secondCollFactor >= riskModule.MIN_COLLATERAL_FACTOR()
                || secondCollFactor <= riskModule.MAX_COLLATERAL_FACTOR()
        );

        uint256[] memory collateralFactors = new uint256[](2);
        collateralFactors[0] = firstCollFactor;
        collateralFactors[1] = secondCollFactor;

        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(firstAssetAddress)
        ).with_key(uint256(0)).checked_write(firstCollFactor);
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(secondAssetAddress)
        ).with_key(uint256(0)).checked_write(secondCollFactor);

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = riskModule.calculateWeightedCollateralValue(addresses, values);

        // Then: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        address assetAddress;

        for (uint256 i; i < addresses.length;) {
            assetAddress = addresses[i];
            calcCollateralValue += values[i].valueInBaseCurrency * collateralFactors[i];
            unchecked {
                ++i;
            }
        }

        calcCollateralValue = calcCollateralValue / 100;

        assertEq(collateralValue, calcCollateralValue);
    }

    function testSuccess_calculateWeightedCollateralValue_smallAmountSmallValue() public {
        // Given: The address of assets and the values of assets. One of the values of assets are zero
        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = 0;
        values[1].valueInBaseCurrency = 1;

        // When: Calculation of the collateral factor
        uint256 collateralValue = riskModule.calculateWeightedCollateralValue(addresses, values);

        // Then: Collateral value is zero, since the values are zero
        assertEq(collateralValue, 0);
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

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        RiskModule.AssetValueRisk[] memory values = new RiskModule.AssetValueRisk[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        riskModule.calculateWeightedCollateralValue(addresses, values);
    }
}
