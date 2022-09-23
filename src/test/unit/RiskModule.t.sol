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
        ).checked_write(110);
        stdstore.target(address(riskModule)).sig(riskModule.liquidationThresholds.selector).with_key(
            address(secondAssetAddress)
        ).checked_write(110);

        // Set collateral factor
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(firstAssetAddress)
        ).checked_write(150);
        stdstore.target(address(riskModule)).sig(riskModule.collateralFactors.selector).with_key(
            address(secondAssetAddress)
        ).checked_write(150);

        vm.stopPrank();
    }

    function testCalculateWeightedLiquidationThresholdSuccess(uint240 firstValue, uint240 secondValue) public {
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
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);

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
            calcLiqThres = riskModule.getLiquidationThreshold(assetAddress);
            calcLiqThreshold += values[i] * uint256(calcLiqThres);
            unchecked {
                ++i;
            }
        }
        calcLiqThreshold = calcLiqThreshold / totalValue;

        assertEq(liqThres, calcLiqThreshold);
    }

    function testCalculateWeightedLiquidationThresholdFail() public {
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
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testCalculateWeightedLiquidationThresholdFaiArithmetic(uint8 firstValueShift, uint8 secondValueShift)
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
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
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
        uint16 liqThreshold = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testCalculateWeightedCollateralFactorSuccess(uint240 firstValue, uint240 secondValue) public {
        // Given: 2 Assets with 2 values and values has to be bigger than zero for success.
        // Values are uint240 to prevent overflow in multiplication
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When: The collateral factor is calculated with given values
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);

        // Then: The collateral factor has to be bigger than zero
        assertTrue(collFactor > 0);

        // It should be equal to calculated collateral factor
        uint256 calcCollFactor;
        uint16 calcCollFact;
        uint256 totalValue;
        address assetAddress;

        for (uint256 i; i < addresses.length;) {
            totalValue += values[i];
            assetAddress = addresses[i];
            calcCollFact = riskModule.getCollateralFactor(assetAddress);
            calcCollFactor += values[i].mulDivDown(100, uint256(calcCollFact));
            unchecked {
                ++i;
            }
        }
        calcCollFactor = calcCollFactor / totalValue;

        assertEq(collFactor, calcCollFact);
    }

    function testCalculateWeightedCollateralFactorFail() public {
        // Given: The address of assets and the values of assets. The values of assets are zero
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAssetAddress;
        addresses[1] = secondAssetAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        // When Then: Calculation of the collateral factor should fail since the total value can't be zero
        vm.expectRevert("RM_CWCF: Total asset value must be bigger than zero");
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }

    function testCalculateWeightedCollateralFactorFailArithmetic(uint8 firstValueShift, uint8 secondValueShift)
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
        vm.expectRevert(stdError.arithmeticError);
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }

    function testRevert_calculateWeightedCollateralFactor_ZeroNotPossible(
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
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }
}
