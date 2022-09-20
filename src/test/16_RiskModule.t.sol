/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/forge-std/src/Test.sol";
import "../RiskModule.sol";
import "./gasTests/BuyVault1.sol";

contract RiskModuleTest is Test {
    using stdStorage for StdStorage;

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
        uint256 firstValue,
        uint256 secondValue
    )
        public
    {
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        vm.assume(firstValue < 100_000_000_000_000 * 10 ** 18);
        vm.assume(secondValue < 100_000_000_000_000 * 10 ** 18);

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);

        assertTrue(liqThres > 0);
    }

    function testCalculateWeightedLiquidationThresholdFail(address firstAsset, address secondAsset) public {
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        vm.expectRevert("RM_CWLT: Total asset value must be bigger than zero");
        uint16 liqThres = riskModule.calculateWeightedLiquidationThreshold(addresses, values);
    }

    function testCalculateWeightedCollateralFactorSuccess(
        address firstAsset,
        address secondAsset,
        uint256 firstValue,
        uint256 secondValue
    )
        public
    {
        vm.assume(firstValue > 0); // value of the asset can not be zero
        vm.assume(secondValue > 0); // value of the asset can not be zero

        vm.assume(firstValue < 100_000_000_000_000 * 10 ** 18);
        vm.assume(secondValue < 100_000_000_000_000 * 10 ** 18);

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);

        assertTrue(collFactor > 0);
    }

    function testCalculateWeightedCollateralFactorFail(address firstAsset, address secondAsset) public {
        uint256 firstValue = 0;
        uint256 secondValue = 0;

        address[] memory addresses = new address[](2);
        addresses[0] = firstAsset;
        addresses[1] = secondAsset;

        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = secondValue;

        vm.expectRevert("RM_CWCF: Total asset value must be bigger than zero");
        uint16 collFactor = riskModule.calculateWeightedCollateralFactor(addresses, values);
    }
}
