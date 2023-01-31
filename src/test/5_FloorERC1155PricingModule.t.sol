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
        mainRegistry = new mainRegistryExtension(address(factory));
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(floorERC1155PricingModule));
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset

        // Then: addAsset should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset twice
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.expectRevert("PM1155_AA: already added");
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with empty list credit ratings
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
        assertEq(floorERC1155PricingModule.assetsInPricingModule(0), address(interleave));
        (uint256 id, address[] memory oracles) = floorERC1155PricingModule.getAssetInformation(address(interleave));
        assertEq(id, 1);
        for (uint256 i; i < oracleInterleaveToEthEthToUsd.length; ++i) {
            assertEq(oracles[i], oracleInterleaveToEthEthToUsd[i]);
        }
        assertTrue(floorERC1155PricingModule.isAllowListed(address(interleave), 1));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_FACTOR
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, riskVars_, type(uint128).max
        );
        vm.stopPrank();

        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_FACTOR
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with full list credit ratings
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(interleave)));
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_isAllowListed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: isAllowListed for address(interleave) should return true
        assertTrue(floorERC1155PricingModule.isAllowListed(address(interleave), 1));
    }

    function testSuccess_isAllowListed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isAllowListed for randomAsset should return false
        assertTrue(!floorERC1155PricingModule.isAllowListed(randomAsset, 1));
    }

    function testSuccess_isAllowListed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is not 1
        vm.assume(id != 1);
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: isAllowListed for address(interlave) should return false
        assertTrue(!floorERC1155PricingModule.isAllowListed(address(interleave), id));
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress_, uint128 amount, address vault)
        public
    {
        vm.prank(creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC1155PricingModule.processDeposit(vault, address(interleave), 1, amount);
        vm.stopPrank();
    }

    function testRevert_processDeposit_OverExposure(uint128 amount, uint128 maxExposure, address vault) public {
        vm.assume(maxExposure > 0); //Asset is whitelisted
        vm.assume(amount > maxExposure);
        vm.prank(creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, maxExposure
        );

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PM1155_PD: Exposure not in limits");
        floorERC1155PricingModule.processDeposit(vault, address(interleave), 1, amount);
        vm.stopPrank();
    }

    function testRevert_processDeposit_WrongID(uint256 assetId, uint128 amount, address vault) public {
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(interleave), 0, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PM1155_PD: ID not allowed");
        floorERC1155PricingModule.processDeposit(vault, address(interleave), assetId, amount);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC1155PricingModule.exposure(address(interleave));
        assertEq(actualExposure, 0);
    }

    function testSuccess_processDeposit_Positive(uint128 amount, address vault) public {
        vm.prank(creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(address(mainRegistry));
        floorERC1155PricingModule.processDeposit(vault, address(interleave), 1, amount);

        (, uint128 actualExposure) = floorERC1155PricingModule.exposure(address(interleave));
        assertEq(actualExposure, amount);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountInterleave) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave * rateInterleaveToEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleInterleaveToEthDecimals + Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(interleave),
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
        // Given: creatorAddress calls addAsset, expectedValueInUsd is zero
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency =
            (amountInterleave * rateInterleaveToEth * Constants.WAD) / 10 ** (Constants.oracleInterleaveToEthDecimals);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(interleave),
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
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave * rateInterleaveToEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleInterleaveToEthDecimals + Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(interleave),
            assetId: 1,
            assetAmount: amountInterleave,
            baseCurrency: uint8(Constants.DaiBaseCurrency)
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
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (
            (rateInterleaveToEthNew * Constants.WAD) / 10 ** Constants.oracleInterleaveToEthDecimals
        ) * amountInterleave;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(interleave),
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

    function testRevert_getValue_Overflow(uint256 amountInterleave, uint256 rateInterleaveToEthNew) public {
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
        floorERC1155PricingModule.addAsset(
            address(interleave), 1, oracleInterleaveToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(interleave),
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
