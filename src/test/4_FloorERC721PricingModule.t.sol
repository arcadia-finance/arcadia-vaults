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

        floorERC721PricingModule = new FloorERC721PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
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
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        // Given:
        vm.startPrank(creatorAddress);
        // When: creatorAddress addAsset twice
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.expectRevert("PM721_AA: already added");
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with empty list credit ratings
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(bayc) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
        assertEq(floorERC721PricingModule.assetsInPricingModule(0), address(bayc));
        (uint256 idRangeStart, uint256 idRangeEnd, address[] memory oracles) =
            floorERC721PricingModule.getAssetInformation(address(bayc));
        assertEq(idRangeStart, 0);
        assertEq(idRangeEnd, type(uint256).max);
        for (uint256 i; i < oracleWbaycToEthEthToUsd.length; ++i) {
            assertEq(oracles[i], oracleWbaycToEthEthToUsd[i]);
        }
        assertTrue(floorERC721PricingModule.isAllowListed(address(bayc), 0));
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
        // When: creatorAddress calls addAsset with wrong number of credits

        // Then: addAsset should add asset
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars_, type(uint128).max
        );
        vm.stopPrank();

        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_FACTOR
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addAsset with full list credit ratings
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(bayc) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(bayc)));
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_isAllowListed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.prank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(
            address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        // Then: address(bayc) should return true on isAllowListed for id's 0 to 9999
        assertTrue(floorERC721PricingModule.isAllowListed(address(bayc), 0));
        assertTrue(floorERC721PricingModule.isAllowListed(address(bayc), 9999));
        assertTrue(floorERC721PricingModule.isAllowListed(address(bayc), 5000));
    }

    function testSuccess_isWhiteListed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isAllowListed for randomAsset should return false
        assertTrue(!floorERC721PricingModule.isAllowListed(randomAsset, 0));
    }

    function testSuccess_isAllowListed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is lower than 10 or bigger than 1000
        vm.assume(id < 10 || id > 1000);
        vm.prank(creatorAddress);
        // When: creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(
            address(bayc), 10, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );

        // Then: isAllowListed for address(bayc) should return false
        assertTrue(!floorERC721PricingModule.isAllowListed(address(bayc), id));
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress_, uint256 assetId) public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);
        vm.stopPrank();
    }

    function testRevert_processDeposit_OverExposure(uint256 assetId) public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, 1);

        vm.startPrank(address(mainRegistry));
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);

        vm.expectRevert("PM721_PD: Exposure not in limits");
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);
        vm.stopPrank();
    }

    function testRevert_processDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 0); //Not in range
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(address(bayc), 0, 0, oracleWbaycToEthEthToUsd, riskVars, 1);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PM721_PD: ID not allowed");
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(bayc));
        assertEq(actualExposure, 0);
    }

    function testSuccess_processDeposit_Positive(uint256 assetId) public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, 1);

        vm.prank(address(mainRegistry));
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(bayc));
        assertEq(actualExposure, 1);
    }

    function testRevert_processWithdrawal_NonMainRegistry(address unprivilegedAddress_) public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processWithdrawal(address(bayc), 1, 1);
        vm.stopPrank();
    }

    function testSuccess_processWithdrawal(uint256 assetId) public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.addAsset(address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, riskVars, 1);

        vm.prank(address(mainRegistry));
        floorERC721PricingModule.processDeposit(address(bayc), assetId, 1);
        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(bayc));
        assertEq(actualExposure, 1);

        vm.prank(address(mainRegistry));
        floorERC721PricingModule.processWithdrawal(address(bayc), 1, 1);
        (, actualExposure) = floorERC721PricingModule.exposure(address(bayc));
        assertEq(actualExposure, 0);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset, expectedValueInBaseCurrency is zero
        floorERC721PricingModule.addAsset(
            address(bayc), 0, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
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
        floorERC721PricingModule.addAsset(
            address(bayc), 0, 999, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
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
        floorERC721PricingModule.addAsset(
            address(mayc), 0, 999, oracleWmaycToUsdArr, emptyRiskVarInput, type(uint128).max
        );
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
