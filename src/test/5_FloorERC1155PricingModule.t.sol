/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract FloorERC1155PricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    //this is a before
    constructor() DeployArcadiaVaults() {}

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            new MainRegistry.AssetRisk[](0)
        );

        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(floorERC1155PricingModule));
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_NonOwnerAddsAsset(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls setAssetInformation

        // Then: setAssetInformation should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );

        vm.stopPrank();
    }

    function testRevert_setAssetInformation_OwnerAddsAssetWithWrongNumberOfRiskVariables() public {
        vm.startPrank(creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_THRESHOLD
        uint16[] memory collateralFactors = new uint16[](1);
        collateralFactors[0] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16[] memory liquidationThresholds = new uint16[](1);
        liquidationThresholds[0] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        // When: creatorAddress calls setAssetInformation with wrong number of credits

        // Then: setAssetInformation should revert with "PM1155_SRV: LENGTH_MISMATCH"
        vm.expectRevert("PM1155_SRV: LENGTH_MISMATCH");
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: collateralFactors,
                assetLiquidationThresholds: liquidationThresholds
            })
        );

        vm.stopPrank();
    }

    function testSuccess_setAssetInformation_OwnerAddsAssetWithEmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls setAssetInformation with empty list credit ratings
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        // Then: inPricingModule for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
    }

    function testSuccess_setAssetInformation_OwnerAddsAssetWithFullListRiskVariables() public {
        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_THRESHOLD
        vm.startPrank(creatorAddress);
        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        collateralFactors[1] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        liquidationThresholds[1] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        // When: creatorAddress calls setAssetInformation with full list credit ratings
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: collateralFactors,
                assetLiquidationThresholds: liquidationThresholds
            })
        );
        vm.stopPrank();

        // Then: inPricingModule for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
    }

    function testSuccess_setAssetInformation_OwnerOverwritesExistingAsset() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls setAssetInformation twice
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        // Then: inPricingModule for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
    }

    function testSuccess_isWhiteListed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls setAssetInformation
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        // Then: isWhiteListed for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.isWhiteListed(address(interleave), 1));
    }

    function testSuccess_isWhiteListed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isWhiteListed for randomAsset should return false
        assertTrue(!floorERC1155PricingModule.isWhiteListed(randomAsset, 1));
    }

    function testSuccess_isWhiteListed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is not 1
        vm.assume(id != 1);
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls setAssetInformation
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        // Then: isWhiteListed for address(interlave) should return false
        assertTrue(!floorERC1155PricingModule.isWhiteListed(address(interleave), id));
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountInterleave) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls setAssetInformation, expectedValueInBaseCurrency is zero
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave * rateInterleaveToEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleInterleaveToEthDecimals + Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_returnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(uint128 amountInterleave) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls setAssetInformation, expectedValueInUsd is zero
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency =
            (amountInterleave * rateInterleaveToEth * Constants.WAD) / 10 ** (Constants.oracleInterleaveToEthDecimals);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountInterleave) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls setAssetInformation, expectedValueInBaseCurrency is zero
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave * rateInterleaveToEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleInterleaveToEthDecimals + Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.SafemoonBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnValue(uint256 amountInterleave, uint256 rateInterleaveToEthNew) public {
        // Given: rateInterleaveToEthNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD
        vm.assume(rateInterleaveToEthNew <= uint256(type(int256).max));
        vm.assume(rateInterleaveToEthNew <= type(uint256).max / Constants.WAD);

        if (rateInterleaveToEthNew == 0) {
            vm.assume(uint256(amountInterleave) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountInterleave)
                    <= type(uint256).max / Constants.WAD * 10 ** Constants.oracleInterleaveToEthDecimals
                        / uint256(rateInterleaveToEthNew)
            );
        }

        vm.startPrank(oracleOwner);
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEthNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (
            (rateInterleaveToEthNew * Constants.WAD) / 10 ** Constants.oracleInterleaveToEthDecimals
        ) * amountInterleave;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testRevert_getValue_ReturnValueOverflow(uint256 amountInterleave, uint256 rateInterleaveToEthNew) public {
        // Given: rateInterleaveToEthNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD and bigger than zero
        vm.assume(rateInterleaveToEthNew <= uint256(type(int256).max));
        vm.assume(rateInterleaveToEthNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateInterleaveToEthNew > 0);

        vm.assume(
            amountInterleave
                > type(uint256).max / Constants.WAD * 10 ** Constants.oracleInterleaveToEthDecimals
                    / uint256(rateInterleaveToEthNew)
        );

        vm.startPrank(oracleOwner);
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEthNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called

        // Then: getValue should be reverted
        vm.expectRevert(stdError.arithmeticError);
        floorERC1155PricingModule.getValue(getValueInput);
    }
}
