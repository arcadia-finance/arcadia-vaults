/**
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/forge-std/src/Test.sol";
import "../RiskModule.sol";


contract RiskModuleTest is Test {
    using stdStorage for StdStorage;

    address public creator = address(1);
    address public nonCreator = address(2);

    RiskModule public riskModule;
    // These code will run before all the tests
    constructor() {
        vm.startPrank(creator);
        riskModule = new RiskModule();
        vm.stopPrank();
    }

    function testValidAddAssetWDefaults() public {
        // Given: assetAddress and riskModule
        address assetAddress = address(41);

        // When: Asset is added with default values
        vm.startPrank(creator);
        riskModule.addAsset(assetAddress);
        vm.stopPrank();

        // Then: Collateral factor for the asset should be 2000
        uint128 collateralFactor = riskModule.getCollateralFactor(assetAddress);
        assertEq(collateralFactor, 2000);

    }

    function testInvalidAddAssetWDefaults() public {
        // Given: assetAddress and riskModule
        address assetAddress = address(31);

        // When Then: Asset is added with default values as nonCreator, It should revert
        vm.startPrank(nonCreator);
        vm.expectRevert("Ownable: caller is not the owner");
        riskModule.addAsset(assetAddress);
        vm.stopPrank();

    }

    function testAddingSameAddressAssetShouldRevert() public {
        // Given: assetAddress and riskModule
        address assetAddress = address(41);

        // When: Asset is added with address. It should revert
        vm.startPrank(creator);
        riskModule.addAsset(assetAddress);
        vm.stopPrank();

        // Then: Asset with the same address is added, it should revert
        vm.startPrank(creator);
        vm.expectRevert("RM: Asset is already added");
        riskModule.addAsset(assetAddress);
        vm.stopPrank();

    }
}
