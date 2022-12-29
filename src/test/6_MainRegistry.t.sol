/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import "../utils/StringHelpers.sol";
import "../utils/CompareArrays.sol";

abstract contract MainRegistryTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    //this is a before
    constructor() DeployArcadiaVaults() {}

    //this is a before each
    function setUp() public virtual {
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

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC721PricingModule = new FloorERC721PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
                        DEPLOYMENT
/////////////////////////////////////////////////////////////// */
contract DeploymentTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment_UsdAsBaseCurrency() public {
        // Given: All necessary contracts deployed on setup
        // When:
        // Then: baseCurrencyLabel should return "USD"
        (,, address assetaddress,, string memory baseCurrencyLabel) = mainRegistry.baseCurrencyToInformation(0);
        assertEq(assetaddress, address(0));
        assertTrue(StringHelpers.compareStrings("USD", baseCurrencyLabel));
        assertEq(mainRegistry.assetToBaseCurrency(address(0)), 0);
        assertEq(mainRegistry.baseCurrencies(0), address(0));
    }

    function testSuccess_deployment_BaseCurrencyCounterIsOne() public {
        // Given: All necessary contracts deployed on setup
        // When:
        // Then: baseCurrencyCounter should return 1
        assertEq(1, mainRegistry.baseCurrencyCounter());
    }
}

/* ///////////////////////////////////////////////////////////////
                    EXTERNAL CONTRACTS
/////////////////////////////////////////////////////////////// */
contract ExternalContractsTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_setFactory_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress, creatorAddress deploys Factory contract, calls setNewVaultInfo and confirmNewVaultInfo
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry), 0x0000000000000000000000000000001234567890, Constants.upgradeProof1To2
        );
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls setFactory

        // Then: setFactory should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    function testSuccess_setFactory_MultipleBaseCurrencies() public {
        // Given: creatorAddress calls addBaseCurrency, deploys Factory contract, calls setNewVaultInfo and confirmNewVaultInfo
        vm.startPrank(creatorAddress);
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
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry), 0x0000000000000000000000000000001234567890, Constants.upgradeProof1To2
        );
        factory.confirmNewVaultInfo();
        // When: creatorAddress calls setFactory with address(factory)
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

        // Then: address(factory) should be equal to factoryAddress
        assertEq(address(factory), mainRegistry.factoryAddress());
    }
}

/* ///////////////////////////////////////////////////////////////
                    BASE CURRENCY MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract BaseCurrencyManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_addBaseCurrency_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addBaseCurrency

        // Then: addBaseCurrency should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        vm.stopPrank();
    }

    function testSuccess_addBaseCurrency() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint248).max);

        // When: creatorAddress calls addBaseCurrency
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        vm.stopPrank();

        // Then: baseCurrencyCounter should return 2
        assertEq(2, mainRegistry.baseCurrencyCounter());
    }
}

/* ///////////////////////////////////////////////////////////////
                    PRICE MODULE MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract PriceModuleManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_addPricingModule_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addPricingModule

        // Then: addPricingModule should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testRevert_addPricingModule_AddExistingPricingModule() public {
        // Given: All necessary contracts deployed on setup

        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addPricingModule for address(standardERC20PricingModule)

        // Then: addPricingModule should revert with "MR_APM: PriceMod. not unique"
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.expectRevert("MR_APM: PriceMod. not unique");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testSuccess_addPricingModule() public {
        // Given: All necessary contracts deployed on setup
        // When: creatorAddress calls addPricingModule for address(standardERC20PricingModule)
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();

        // Then: isPricingModule for address(standardERC20PricingModule) should return true
        assertTrue(mainRegistry.isPricingModule(address(standardERC20PricingModule)));
    }
}

/* ///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract AssetManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
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
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testSuccess_assetsUpdatable_DefaultTrue() public {
        // Given: All necessary contracts deployed on setup
        // When:
        // Then: assetsUpdatable should return true
        assertTrue(mainRegistry.assetsUpdatable());
    }

    function testRevert_setAssetsToNonUpdatable_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls setAssetsToNonUpdatable

        // Then: setAssetsToNonUpdatable should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();
    }

    function testSuccess_setAssetsToNonUpdatable() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls setAssetsToNonUpdatable
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        // Then: assetsUpdatable should return false
        assertTrue(!mainRegistry.assetsUpdatable());
    }

    function testRevert_addAsset_NonPricingModule(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not address(standardERC20PricingModule), address(floorERC721PricingModule) or address(floorERC1155PricingModule)
        vm.assume(unprivilegedAddress_ != address(standardERC20PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC721PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC1155PricingModule));
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset
        // Then: addAsset should revert with "Caller is not a Price Module."
        vm.expectRevert("Caller is not a Price Module.");
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        // When: standardERC20PricingModule calls addAsset with input of address(eth)
        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();

        // Then: inMainRegistry for address(eth) should return true
        assertTrue(mainRegistry.inMainRegistry(address(eth)));
    }

    function testSuccess_addAsset_OverwriteAssetPositive() public {
        // Given: creatorAddress calls addPricingModule for floorERC721PricingModule, standardERC20PricingModule calls addAsset
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();

        // When: standardERC20PricingModule calls addAsset
        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();

        // Then: assetToPricingModule for address(eth) should return standardERC20PricingModule
        assertEq(address(standardERC20PricingModule), mainRegistry.assetToPricingModule(address(eth)));

        // When: floorERC721PricingModule calls addAsset
        vm.startPrank(address(floorERC721PricingModule));
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();

        // Then: assetToPricingModule for address(eth) should return address(floorERC721PricingModule)
        assertEq(address(floorERC721PricingModule), mainRegistry.assetToPricingModule(address(eth)));
    }

    function testRevert_addAsset_OverwriteAssetNegative() public {
        // Given: creatorAddress calls addPricingModule and setAssetsToNonUpdatable,
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        // When: standardERC20PricingModule calls addAsset
        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();

        // Then: assetToPricingModule for address(eth) should return address(standardERC20PricingModule)
        assertEq(address(standardERC20PricingModule), mainRegistry.assetToPricingModule(address(eth)));

        vm.startPrank(address(floorERC721PricingModule));
        // When: floorERC721PricingModule calls addAsset
        // Then: addAsset should revert with "MR_AA: Asset not updatable"
        vm.expectRevert("MR_AA: Asset not updatable");
        mainRegistry.addAsset(address(eth));
        vm.stopPrank();

        assertEq(address(standardERC20PricingModule), mainRegistry.assetToPricingModule(address(eth)));
    }
}

/* ///////////////////////////////////////////////////////////////
                    WHITE LIST LOGIC
/////////////////////////////////////////////////////////////// */
contract WhiteListLogicTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
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
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();
    }

    function testSuccess_batchIsWhiteListed_AllAssetsWhiteListed() public {
        // Given: creatorAddress calls addAsset on standardERC20PricingModule and floorERC721PricingModule
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput
        );
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(bayc) and assetIds index 0 is 0, index 1 is 0
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        // Then: batchIsWhiteListed for assetAddresses, assetIds should return true
        assertTrue(mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testRevert_batchIsWhiteListed_NonEqualInputLists() public {
        // Given: creatorAddress calls addAsset for standardERC20PricingModule and floorERC721PricingModule
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput
        );
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(bayc) and assetIds index 0 is 0
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        // Then: batchIsWhiteListed for assetAddresses, assetIds should revert with "LENGTH_MISMATCH"
        vm.expectRevert("LENGTH_MISMATCH");
        mainRegistry.batchIsWhiteListed(assetAddresses, assetIds);
    }

    function testSuccess_batchIsWhiteListed_SingleAssetNotWhitelisted() public {
        // Given: creatorAddress calls addAsset for standardERC20PricingModule and floorERC721PricingModule
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput);
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(bayc) and assetIds index 0 is 0, index 1 is 10000
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 10000;

        // Then: batchIsWhiteListed for assetAddresses, assetIds should return false
        assertTrue(!mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testSuccess_batchIsWhiteListed_AssetNotInMainregistry() public {
        // Given: creatorAddress calls addAsset for standardERC20PricingModule and floorERC721PricingModule
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput);
        vm.stopPrank();

        // When: assetAddresses index 0 is address(safemoon), index 1 is address(bayc) and assetIds index 0 is 0, index 1 is 0
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        // Then: batchIsWhiteListed for assetAddresses, assetIds should return false
        assertTrue(!mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testSuccess_getWhiteList_MultipleAssets() public {
        // Given: creatorAddress calls addAsset for standardERC20PricingModule and floorERC721PricingModule
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput);

        vm.stopPrank();

        // When: expectedWhiteList index 0 is address(eth), index 1 is address(snx), index 2 is address(bayc), actualWhiteList is getWhiteList
        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        // Then: expectedWhiteList should be equal to actualWhiteList
        assertTrue(CompareArrays.compareArrays(expectedWhiteList, actualWhiteList));
    }

    function testSuccess_getWhiteList_RemovalOfAsset() public {
        // Given: creatorAddress calls addAsset for standardERC20PricingModule and floorERC721PricingModule, calls removeFromWhiteList and addToWhiteList for address(snx)
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, emptyRiskVarInput, type(uint248).max);
        floorERC721PricingModule.addAsset(address(bayc), 0, 9999, oracleWbaycToEthEthToUsd, emptyRiskVarInput);

        standardERC20PricingModule.removeFromWhiteList(address(snx));
        standardERC20PricingModule.addToWhiteList(address(snx));
        vm.stopPrank();

        // When: expectedWhiteList index 0 is address(eth), index 1 is address(snx), index 2 is address(bayc)
        // and actualWhiteList is getWhiteList from mainRegistry
        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        // Then: expectedWhiteList should be equal to actualWhiteList
        assertTrue(CompareArrays.compareArrays(expectedWhiteList, actualWhiteList));
    }
}

/* ///////////////////////////////////////////////////////////////
                        PRICING LOGIC
/////////////////////////////////////////////////////////////// */
contract PricingLogicTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
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
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint248).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint248).max);

        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput
        );
        vm.stopPrank();
    }

    function testSucccess_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        // Given: linkDecimals is less than equal to 18, rateEthToUsdNew is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency with emptyList, calls addPricingModule with standardERC20PricingModule,
        // oracleOwner calls transmit with rateEthToUsdNew and rateLinkToUsd
        vm.assume(linkDecimals <= 18);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink
                <= type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD
                    / 10 ** (Constants.oracleEthToUsdDecimals - Constants.oracleLinkToUsdDecimals)
        );
        vm.assume(
            amountLink
                <= (
                    ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals)
                        / 10 ** Constants.oracleLinkToUsdDecimals
                ) * 10 ** linkDecimals
        );

        vm.startPrank(creatorAddress);
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            linkDecimals
        );
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // actualTotalValue is getTotalValue for assetAddresses, assetIds, assetAmounts and Constants.EthBaseCurrency,
        // expectedTotalValue is linkValueInEth
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        uint256 actualTotalValue =
            mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 linkValueInUsd = (assetAmounts[0] * rateLinkToUsd * Constants.WAD)
            / 10 ** Constants.oracleLinkToUsdDecimals / 10 ** linkDecimals;
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsdNew
            / 10 ** (18 - Constants.ethDecimals);

        uint256 expectedTotalValue = linkValueInEth;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdOverflow(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        // Given: linkDecimals is less than oracleEthToUsdDecimals, rateEthToUsdNew is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency, calls addPricingModule with standardERC20PricingModule,
        // oracleOwner calls transmit with rateEthToUsdNew and rateLinkToUsd
        vm.assume(linkDecimals < Constants.oracleEthToUsdDecimals);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink
                > ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals)
                    / 10 ** (Constants.oracleLinkToUsdDecimals - linkDecimals)
        );

        vm.startPrank(creatorAddress);
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            linkDecimals);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint248).max);
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // getTotalValue is called
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        // Then: getTotalValue should revert with arithmetic overflow
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdWithRateZero(uint256 amountLink)
        public
    {
        // Given: amountLink bigger than 0, oracleOwner calls transmit for 0 and rateLinkToUsd
        vm.assume(amountLink > 0);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(0));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // getTotalValue is called
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        // Then: getTotalValue should revert
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);
    }

    function testRevert_getTotalValue_NegativeNonEqualInputLists() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        // Then: getTotalValue should revert with "MR_GTV: LENGTH_MISMATCH"
        vm.expectRevert("MR_GTV: LENGTH_MISMATCH");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 10;

        vm.expectRevert("MR_GTV: LENGTH_MISMATCH");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_NonEqualInputLists() public {
        // Given: assetAddresses index 0 is address(eth), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getListOfValuesPerAsset called

        // Then: getListOfValuesPerAsset should revert with "MR_GLV: LENGTH_MISMATCH"
        vm.expectRevert("MR_GLV: LENGTH_MISMATCH");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 10;

        vm.expectRevert("MR_GLV: LENGTH_MISMATCH");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testRevert_getTotalValue_UnknownBaseCurrency() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(eth), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GTV: Unknown BaseCurrency"
        vm.expectRevert("MR_GTV: Unknown BaseCurrency");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownBaseCurrency() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(eth), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GLV: Unknown BaseCurrency"
        vm.expectRevert("MR_GLV: Unknown BaseCurrency");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getTotalValue_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(safemoon), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GTV: Unknown asset"
        vm.expectRevert("MR_GTV: Unknown asset");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(safemoon), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GLV: Unknown asset"
        vm.expectRevert("MR_GLV: Unknown asset");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testSuccess_getTotalValue() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: oracleOwner calls transmit for rateEthToUsd, rateLinkToUsd and rateWbaycToEth
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(link), index 2 is address(bayc), assetIds index 0, 1 and 2 is 0,
        // assetAmounts index 0 is 10 multiplied by ethDecimals, index 1 is 10 multiplied by linkDecimals, index 2 is 1, actualTotalValue is getTotalValue,
        // expectedTotalValue is ethValueInEth plus linkValueInEth plus baycValueInEth
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256 actualTotalValue =
            mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 ethValueInEth = assetAmounts[0];
        uint256 linkValueInUsd = (Constants.WAD * rateLinkToUsd * assetAmounts[1])
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsd
            / 10 ** (18 - Constants.ethDecimals);
        uint256 baycValueInEth = (Constants.WAD * rateWbaycToEth * assetAmounts[2])
            / 10 ** Constants.oracleWbaycToEthDecimals / 10 ** (18 - Constants.ethDecimals);

        uint256 expectedTotalValue = ethValueInEth + linkValueInEth + baycValueInEth;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testSuccess_getListOfValuesPerAsset() public {
        // Given: oracleOwner calls transmit for rateEthToUsd, rateLinkToUsd and rateWbaycToEth
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(link), index 2 is address(bayc), assetIds index 0, 1 and 2 is 0,
        // assetAmounts index 0 is 10 multiplied by ethDecimals, index 1 is 10 multiplied by linkDecimals, index 2 is 1, actualListOfValuesPerAsset is getListOfValuesPerAsset,
        // expectedListOfValuesPerAsset index 0 is ethValueInEth, index 1 is linkValueInEth, index 2 is baycValueInEth
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        RiskModule.AssetValueAndRiskVariables[] memory actualValuesPerAsset =
            mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 ethValueInEth = assetAmounts[0];
        uint256 linkValueInUsd = (Constants.WAD * rateLinkToUsd * assetAmounts[1])
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsd
            / 10 ** (18 - Constants.ethDecimals);
        uint256 baycValueInEth = (Constants.WAD * rateWbaycToEth * assetAmounts[2])
            / 10 ** Constants.oracleWbaycToEthDecimals / 10 ** (18 - Constants.ethDecimals);

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = ethValueInEth;
        expectedListOfValuesPerAsset[1] = linkValueInEth;
        expectedListOfValuesPerAsset[2] = baycValueInEth;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; i++) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].valueInBaseCurrency;
        }
        // Then: expectedListOfValuesPerAsset array should be equal to actualListOfValuesPerAsset
        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }
}
