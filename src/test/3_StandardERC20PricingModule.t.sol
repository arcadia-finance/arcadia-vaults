/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract StandardERC20PricingModuleTest is DeployArcadiaVaults {
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

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
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

        // Then: addAsset should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset twice
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.expectRevert("PM20_AA: already added");
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_MoreThan18Decimals() public {
        vm.prank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", 19);

        // When: creatorAddress calls addAsset with 19 decimals
        // Then: addAsset should revert with "SSR_SAI: Maximal 18 decimals"
        vm.startPrank(creatorAddress);
        vm.expectRevert("PM20_AA: Maximal 18 decimals");
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, riskVars, type(uint248).max);
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with empty list credit ratings
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        // Then: address(eth) should be inPricingModule
        assertTrue(standardERC20PricingModule.inPricingModule(address(eth)));
        assertEq(standardERC20PricingModule.assetsInPricingModule(0), address(eth));
        (uint64 assetUnit, address[] memory oracles) = standardERC20PricingModule.getAssetInformation(address(eth));
        assertEq(assetUnit, 10 ** uint8(Constants.ethDecimals));
        for (uint256 i; i < oracleEthToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleEthToUsdArr[i]);
        }
        assertTrue(standardERC20PricingModule.isWhiteListed(address(eth), 0));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        // Turn this into invalid uint16
        vm.startPrank(creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_THRESHOLD
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collFactor,
            liquidationThreshold: liqTresh
        });
        // When: creatorAddress calls addAsset with wrong number of credits

        // Then: addAsset should add asset
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, riskVars_, type(uint248).max);
        vm.stopPrank();

        assertTrue(standardERC20PricingModule.inPricingModule(address(eth)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        // Given:
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with full list credit ratings
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, riskVars, type(uint248).max);
        vm.stopPrank();

        // Then: address(eth) should be inPricingModule
        assertTrue(standardERC20PricingModule.inPricingModule(address(eth)));
    }

    function testRevert_setOracles_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        standardERC20PricingModule.setOracles(asset, new address[](0));
        vm.stopPrank();
    }

    function testRevert_setOracles_AssetUnknown(address asset) public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("PM20_SO: asset unknown");
        standardERC20PricingModule.setOracles(asset, new address[](0));
        vm.stopPrank();
    }

    function testSuccess_setOracles() public {
        stdstore.target(address(standardERC20PricingModule)).sig(standardERC20PricingModule.inPricingModule.selector)
            .with_key(address(eth)).checked_write(true);

        vm.prank(creatorAddress);
        standardERC20PricingModule.setOracles(address(eth), oracleEthToUsdArr);

        (, address[] memory oracles) = standardERC20PricingModule.getAssetInformation(address(eth));
        for (uint256 i; i < oracleEthToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleEthToUsdArr[i]);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(eth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC20PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_returnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(uint128 amountSnx) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInUsd is zero
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (amountSnx * rateSnxToEth * Constants.WAD)
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(snx),
            assetId: 0,
            assetAmount: amountSnx,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC20PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountLink) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountLink * rateLinkToUsd * Constants.WAD)
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(link),
            assetId: 0,
            assetAmount: amountLink,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });

        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC20PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue(uint256 rateEthToUsdNew, uint256 amountEth) public {
        // Given: rateEthToUsdNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);

        if (rateEthToUsdNew == 0) {
            vm.assume(uint256(amountEth) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountEth)
                    <= (type(uint256).max / uint256(rateEthToUsdNew) / Constants.WAD)
                        * 10 ** Constants.oracleEthToUsdDecimals
            );
        }

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateEthToUsdNew) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
        ) / 10 ** Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(eth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC20PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testRevert_getValue_Overflow(uint256 rateEthToUsdNew, uint256 amountEth) public {
        // Given: rateEthToUsdNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD and bigger than zero
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateEthToUsdNew > 0);

        vm.assume(
            uint256(amountEth)
                > (type(uint256).max / uint256(rateEthToUsdNew) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals
        );

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(eth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        // When: getValue called

        // Then: getValue should be reverted
        vm.expectRevert(bytes(""));
        standardERC20PricingModule.getValue(getValueInput);
    }
}
