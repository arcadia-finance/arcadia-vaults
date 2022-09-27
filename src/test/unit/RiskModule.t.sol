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
        ).with_key(uint256(0)).checked_write(150);
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(secondAssetAddress)
        ).with_key(uint256(0)).checked_write(150);

        vm.stopPrank();
    }

    function testSuccess_calculateWeightedLiquidationThreshold_Success(uint240 firstValue, uint240 secondValue)
        public
    {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success
        // Values are uint240 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: The liquidation threshold is calculated with given values
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values, 0);

        // Then: The liquidation threshold has to be bigger than zero
        assertTrue(liqThres > 0);

        // It should be equal to calculated liquidity threshold
        uint256 calcLiqThreshold;
        uint16 calcLiqThres;
        uint256 totalValue;
        address assetAddress;

        for (uint256 i; i < addresses.length;) {
            totalValue += values[i];
            assetAddress = addresses[i];
            calcLiqThres = riskModule.getLiquidationThreshold(assetAddress, 0);
            calcLiqThreshold += values[i] * uint256(calcLiqThres);
            unchecked {
                ++i;
            }
        }
        calcLiqThreshold = calcLiqThreshold / totalValue;

        assertEq(liqThres, calcLiqThreshold);
    }

    function testRevert_calculateWeightedLiquidationThreshold_totalAssetValue() public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = firstAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the liquidation threshold should fail since the total value can't be zero
        vm.expectRevert("RM_CWLT: Total asset value must be bigger than zero");
        riskModule.calculateWeightedLiquidationThreshold(addresses, values, 0);
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

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the liquidation threshold should fail and reverted since liquidation calculation overflow
        vm.expectRevert(stdError.arithmeticError);
        riskModule.calculateWeightedLiquidationThreshold(addresses, values, 0);
    }

    function testRevert_calculateWeightedLiquidationThreshold_ZeroNotPossible(
        address firstAsset,
        address secondAsset,
        uint240 firstValue,
        uint240 secondValue
    ) public {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success.
        // Values are uint240 to prevent overflow in multiplication
        // Assets are not in the liquidation threshold mapping
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        vm.assume(firstAsset != firstAssetAddress);
        vm.assume(secondAsset != secondAssetAddress);

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert("RM_GLT: Liquidation Threshold has to bigger than zero");
        riskModule.calculateWeightedLiquidationThreshold(addresses, values, 0);
    }

    function testSuccess_calculateWeightedCollateralFactor_Success(uint256 firstValue, uint256 secondValue) public {
        // Given: 2 Assets with 2 values and values has to be greater than = 1 * VARIABLE_DECIMAL / ColFact
        vm.assume(firstValue > 1); // value of asset should be greater than = 1 * VARIABLE_DECIMAL / ColFact
        vm.assume(secondValue > 1); // value of asset should be greater than = 1 * VARIABLE_DECIMAL / ColFact
        vm.assume(firstValue < type(uint256).max / 100); // to prevent the overflow when multiplied with VARIABLE_DECIMAL
        vm.assume(secondValue < type(uint256).max / 100); // to prevent the overflow when multiplied with VARIABLE_DECIMAL

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = riskModule.calculateWeightedCollateralValue(addresses, values, 0);

        // Then: The collateral factor has to be bigger than zero
        assertTrue(collateralValue > 0);

        // And: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        uint16 colFact;
        address assetAddress;

        for (uint256 i; i < addresses.length;) {
            assetAddress = addresses[i];
            colFact = riskModule.getCollateralFactor(assetAddress, 0);
            calcCollateralValue += values[i].mulDivDown(100, uint256(colFact));
            unchecked {
                ++i;
            }
        }

        assertEq(collateralValue, calcCollateralValue);
    }

    function testSuccess_calculateWeightedCollateralValue_smallAmountSmallValue(uint256 firstValue, uint256 secondValue)
        public
    {
        // Given: The address of assets and the values of assets. The values of assets are zero
        vm.assume(firstValue < 2); // value of asset cannot be smaller than = 1 * VARIABLE_DECIMAL / ColFact
        vm.assume(secondValue < 2); // value of asset cannot be smaller than = 1 * VARIABLE_DECIMAL / ColFact

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: Calculation of the collateral factor
        uint256 collateralValue = riskModule.calculateWeightedCollateralValue(addresses, values, 0);

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

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert(bytes(""));
        riskModule.calculateWeightedCollateralValue(addresses, values, 0);
    }

    function testRevert_calculateWeightedCollateralValue_ZeroNotPossible(
        address firstAsset,
        address secondAsset,
        uint240 firstValue,
        uint240 secondValue
    ) public {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success.
        // Values are uint240 to prevent overflow in multiplication
        // Assets are not in the collateralfactors mapping
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        vm.assume(firstAsset != firstAssetAddress);
        vm.assume(secondAsset != secondAssetAddress);

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail and reverted since collateral calculation overflow
        vm.expectRevert("RM_GCF: Collateral Factor has to bigger than zero");
        riskModule.calculateWeightedCollateralValue(addresses, values, 0);
    }
}
