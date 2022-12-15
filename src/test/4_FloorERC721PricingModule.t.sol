/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract FloorERC721PricingModuleTest is DeployArcadiaVaults {
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
            }),
            new MainRegistry.AssetRisk[](0)
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

        floorERC721PricingModule = new FloorERC721PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();
    }

    function testRevert_addAsset_NonOwnerAddsAsset(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset

        // Then: addAsset should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testRevert_addAsset_OwnerAddsAssetWithWrongNumberOfRiskVariables() public { //Todo: Will become testSuccess
        vm.startPrank(creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_THRESHOLD
        PricingModule.RiskVarInput[] memory collateralFactors_ = new PricingModule.RiskVarInput[](1);
        collateralFactors_[0] = PricingModule.RiskVarInput({baseCurrency:0, value:collFactor});
        PricingModule.RiskVarInput[] memory liquidationThresholds_ = new PricingModule.RiskVarInput[](1);
        liquidationThresholds_[0] = PricingModule.RiskVarInput({baseCurrency:0, value:liqTresh});
        // When: creatorAddress calls addAsset with wrong number of credits

        // Then: addAsset should revert with "PM721_SRV: LENGTH_MISMATCH"
        vm.expectRevert("APM_SRV: LENGTH_MISMATCH");
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, collateralFactors_, liquidationThresholds_);
        vm.stopPrank();
    }

    function testSuccess_addAsset_OwnerAddsAssetWithEmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with empty list credit ratings
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        // Then: inPricingModule for address(bayc) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
    }

    function testSuccess_addAsset_OwnerAddsAssetWithFullListRiskVariables() public {
        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_THRESHOLD
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with full list credit ratings
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, collateralFactors, liquidationThresholds);
        vm.stopPrank();

        // Then: inPricingModule for address(bayc) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
    }

    function testSuccess_addAsset_OwnerOverwritesExistingAsset() public { //Todo: Will become testRevert
        // Given:
        vm.startPrank(creatorAddress);
        // When: creatorAddress addAsset twice
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        // Then: address(bayc) should be inPricingModule
        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
    }

    function testSuccess_isWhiteListed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        // Then: address(bayc) should return true on isWhiteListed for id's 0 to 9999
        assertTrue(floorERC721PricingModule.isWhiteListed(address(bayc), 0));
        assertTrue(floorERC721PricingModule.isWhiteListed(address(bayc), 9999));
        assertTrue(floorERC721PricingModule.isWhiteListed(address(bayc), 5000));
    }

    function testSuccess_isWhiteListed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isWhiteListed for randomAsset should return false
        assertTrue(!floorERC721PricingModule.isWhiteListed(randomAsset, 0));
    }

    function testSuccess_isWhiteListed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is lower than 10 or bigger than 1000
        vm.assume(id < 10 || id > 1000);
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(address(bayc), 10, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        // Then: isWhiteListed for address(bayc) should return false
        assertTrue(!floorERC721PricingModule.isWhiteListed(address(bayc), id));
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        floorERC721PricingModule.addAsset(address(bayc), 0, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        uint256 expectedValueInUsd = (rateWbaycToEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleWbaycToEthDecimals + Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(bayc),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC721PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnBaseCurrencyValueWhenBaseCurrencyIsNotUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInUsd is zero
        floorERC721PricingModule.addAsset(address(bayc), 0, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency =
            (rateWbaycToEth * Constants.WAD) / 10 ** Constants.oracleWbaycToEthDecimals;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(bayc),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC721PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsNotUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        floorERC721PricingModule.addAsset(address(mayc), 0, 999, oracleWmaycToUsdArr, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();

        uint256 expectedValueInUsd = (rateWmaycToUsd * Constants.WAD) / 10 ** Constants.oracleWmaycToUsdDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(mayc),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        // When: getValue called
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            floorERC721PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd, actualValueInBaseCurrency should be equal to expectedValueInBaseCurrency
        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }
}
