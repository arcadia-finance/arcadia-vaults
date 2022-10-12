/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../AssetRegistry/FloorERC721PricingModule.sol";
import "../AssetRegistry/StandardERC20PricingModule.sol";
import "../AssetRegistry/FloorERC1155PricingModule.sol";
import "../OracleHub.sol";
import "../Factory.sol";
import "../utils/Constants.sol";
import "../utils/StringHelpers.sol";
import "../utils/CompareArrays.sol";
import "../mockups/ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

abstract contract MainRegistryTest is Test {
    using stdStorage for StdStorage;

    ERC20Mock public dai;
    ERC20Mock public eth;
    ERC20Mock public snx;
    ERC20Mock public link;
    ERC20Mock public safemoon;
    ERC721Mock public bayc;
    ERC721Mock public mayc;
    ERC721Mock public dickButs;
    ERC20Mock public wbayc;
    ERC20Mock public wmayc;
    ERC1155Mock public interleave;
    OracleHub public oracleHub;
    ArcadiaOracle public oracleDaiToUsd;
    ArcadiaOracle public oracleEthToUsd;
    ArcadiaOracle public oracleLinkToUsd;
    ArcadiaOracle public oracleSnxToEth;
    ArcadiaOracle public oracleWbaycToEth;
    ArcadiaOracle public oracleWmaycToUsd;
    ArcadiaOracle public oracleInterleaveToEth;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    FloorERC721PricingModule public floorERC721PricingModule;
    FloorERC1155PricingModule public floorERC1155PricingModule;
    Factory public factory;

    address public creatorAddress = address(1);
    address public tokenCreatorAddress = address(2);
    address public oracleOwner = address(3);

    uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
    uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10 ** Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10 ** Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10 ** Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth = 1 * 10 ** (Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    uint256[] emptyList = new uint256[](0);
    uint16[] emptyListUint16 = new uint16[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);

        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );
        safemoon = new ERC20Mock(
            "Safemoon Mock",
            "mSFMN",
            uint8(Constants.safemoonDecimals)
        );
        bayc = new ERC721Mock("BAYC Mock", "mBAYC");
        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        dickButs = new ERC721Mock("DickButs Mock", "mDICK");
        wbayc = new ERC20Mock(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals)
        );
        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");

        vm.stopPrank();

        vm.prank(creatorAddress);
        oracleHub = new OracleHub();

        oracleDaiToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD", rateDaiToUsd);
        oracleEthToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD", rateEthToUsd);
        oracleLinkToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleLinkToUsdDecimals), "LINK / USD", rateLinkToUsd);
        oracleSnxToEth =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleSnxToEthDecimals), "SNX / ETH", rateSnxToEth);
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals), "WBAYC / ETH", rateWbaycToEth
        );
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals), "WBAYC / USD", rateWmaycToUsd
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals), "INTERLEAVE / ETH", rateInterleaveToEth
        );

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWbaycToEthUnit),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "WBAYC",
                baseAsset: "ETH",
                oracleAddress: address(oracleWbaycToEth),
                quoteAssetAddress: address(wbayc),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWmaycToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "WMAYC",
                baseAsset: "USD",
                oracleAddress: address(oracleWmaycToUsd),
                quoteAssetAddress: address(wmayc),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleInterleaveToEthUnit),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "INTERLEAVE",
                baseAsset: "ETH",
                oracleAddress: address(oracleInterleaveToEth),
                quoteAssetAddress: address(interleave),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        oracleDaiToUsdArr[0] = address(oracleDaiToUsd);

        oracleEthToUsdArr[0] = address(oracleEthToUsd);

        oracleLinkToUsdArr[0] = address(oracleLinkToUsd);

        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);

        oracleWbaycToEthEthToUsd[0] = address(oracleWbaycToEth);
        oracleWbaycToEthEthToUsd[1] = address(oracleEthToUsd);

        oracleWmaycToUsdArr[0] = address(oracleWmaycToUsd);

        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);
    }

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
        (,,,, string memory baseCurrencyLabel) = mainRegistry.baseCurrencyToInformation(0);
        assertTrue(StringHelpers.compareStrings("USD", baseCurrencyLabel));
    }

    function testSuccess_deployment_BaseCurrencyCounterIsZero() public {
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

    function testRevert_setFactory_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry), 0x0000000000000000000000000000001234567890, Constants.upgradeProof1To2
        );
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    function testSuccess_setFactory_MultipleBaseCurrencies() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry), 0x0000000000000000000000000000001234567890, Constants.upgradeProof1To2
        );
        factory.confirmNewVaultInfo();
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

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

    function testRevert_addBaseCurrency_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();
    }

    function testRevert_addBaseCurrency_WrongNumberOfRiskVariables() public {
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16 liqTresh = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = collFactor;
        collateralFactors[1] = collFactor;
        collateralFactors[2] = collFactor;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = liqTresh;
        liquidationThresholds[1] = liqTresh;
        liquidationThresholds[2] = liqTresh;

        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );

        vm.expectRevert("MR_ABC: LENGTH_MISMATCH");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();
    }

    function testRevert_addBaseCurrency_NonValidRiskVariable() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );

        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = 15000;
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.expectRevert("MR_ABC: Coll.Fact not in limits");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            collateralFactors,
            liquidationThresholds
        );

        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        liquidationThresholds[0] = 11000;

        vm.expectRevert("MR_ABC: Liq.Thres not in limits");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();
    }

    function testSuccess_addBaseCurrency_EmptyListOfRiskVariables() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );

        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        assertEq(3, mainRegistry.baseCurrencyCounter());
    }

    function testSuccess_addBaseCurrency_FullListOfRiskVariables() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );

        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();

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

    function testRevert_addPricingModule_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testRevert_addPricingModule_AddExistingPricingModule() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.expectRevert("MR_APM: PriceMod. not unique");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testSuccess_addPricingModule() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();

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
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testSuccess_assetsUpdatable_DefaultTrue() public {
        assertTrue(mainRegistry.assetsUpdatable());
    }

    function testRevert_setAssetsToNonUpdatable_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();
    }

    function testSuccess_setAssetsToNonUpdatable() public {
        vm.startPrank(creatorAddress);
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        assertTrue(!mainRegistry.assetsUpdatable());
    }

    function testRevert_addAsset_NonPricingModule(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != address(standardERC20PricingModule));
        vm.assume(unprivilegedAddress != address(floorERC721PricingModule));
        vm.assume(unprivilegedAddress != address(floorERC1155PricingModule));
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Caller is not a Price Module.");
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
        vm.stopPrank();
    }

    function testRevert_addAsset_WrongNumberOfRiskVariables() public {
        uint16[] memory collateralFactors = new uint16[](1);
        uint16[] memory liquidationThresholds = new uint16[](1);
        collateralFactors[0] = 1;
        liquidationThresholds[0] = 1;

        vm.startPrank(address(standardERC20PricingModule));
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        mainRegistry.addAsset(address(eth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testRevert_addAsset_RiskVariablesTooSmall() public {
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[2] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = 99;
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[2] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.startPrank(address(standardERC20PricingModule));
        vm.expectRevert("MR_AA: Liq.Thres not in limits");
        mainRegistry.addAsset(address(eth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testRevert_addAsset_RiskVariablesTooBig() public {
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = 15000;
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[2] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[2] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.startPrank(address(standardERC20PricingModule));
        vm.expectRevert("MR_AA: Coll.Fact not in limits");
        mainRegistry.addAsset(address(eth), collateralFactors, liquidationThresholds);
        vm.stopPrank();

        vm.startPrank(address(standardERC20PricingModule));
        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        liquidationThresholds[0] = 11000;
        vm.expectRevert("MR_AA: Liq.Thres not in limits");
        mainRegistry.addAsset(address(eth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertTrue(mainRegistry.inMainRegistry(address(eth)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16 liqTresh = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = collFactor;
        collateralFactors[1] = collFactor;
        collateralFactors[2] = collFactor;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = liqTresh;
        liquidationThresholds[1] = liqTresh;
        liquidationThresholds[2] = liqTresh;

        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testSuccess_addAsset_OverwriteAssetPositive() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();

        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertEq(address(standardERC20PricingModule), mainRegistry.assetToPricingModule(address(eth)));

        vm.startPrank(address(floorERC721PricingModule));
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertEq(address(floorERC721PricingModule), mainRegistry.assetToPricingModule(address(eth)));
    }

    function testRevert_addAsset_OverwriteAssetNegative() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertEq(address(standardERC20PricingModule), mainRegistry.assetToPricingModule(address(eth)));

        vm.startPrank(address(floorERC721PricingModule));
        vm.expectRevert("MR_AA: Asset not updatable");
        mainRegistry.addAsset(address(eth), emptyListUint16, emptyListUint16);
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
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();
    }

    function testSuccess_batchIsWhiteListed_AllAssetsWhiteListed() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assertTrue(mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testRevert_batchIsWhiteListed_NonEqualInputLists() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        vm.expectRevert("LENGTH_MISMATCH");
        mainRegistry.batchIsWhiteListed(assetAddresses, assetIds);
    }

    function testSuccess_batchIsWhiteListed_SingleAssetNotWhitelisted() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 10000;

        assertTrue(!mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testSuccess_batchIsWhiteListed_AssetNotInMainregistry() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assertTrue(!mainRegistry.batchIsWhiteListed(assetAddresses, assetIds));
    }

    function testSuccess_getWhiteList_MultipleAssets() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(CompareArrays.compareArrays(expectedWhiteList, actualWhiteList));
    }

    function testSuccess_getWhiteList_RemovalOfAsset() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.removeFromWhiteList(address(snx));
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(CompareArrays.compareArrays(expectedWhiteList, actualWhiteList));
    }

    function testSuccess_getWhiteList_RemovalAndRestoringOfAsset() public {
        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.removeFromWhiteList(address(snx));
        standardERC20PricingModule.addToWhiteList(address(snx));
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(CompareArrays.compareArrays(expectedWhiteList, actualWhiteList));
    }
}

/* ///////////////////////////////////////////////////////////////
                RISK VARIABLES MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract RiskVariablesManagementTest is MainRegistryTest {
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
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();
    }

    function testRevert_batchSetRiskVariables_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory baseCurrencies = new uint256[](2);
        baseCurrencies[0] = Constants.UsdBaseCurrency;
        baseCurrencies[1] = Constants.EthBaseCurrency;

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16 liqTresh = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = collFactor;
        collateralFactors[1] = collFactor;
        collateralFactors[2] = collFactor;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = liqTresh;
        liquidationThresholds[1] = liqTresh;
        liquidationThresholds[2] = liqTresh;

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testRevert_batchSetRiskVariables_NonEqualInputLists() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory baseCurrencies = new uint256[](1);
        baseCurrencies[0] = Constants.UsdBaseCurrency;

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16 liqTresh = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = collFactor;
        collateralFactors[1] = collFactor;
        collateralFactors[2] = collFactor;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = liqTresh;
        liquidationThresholds[1] = liqTresh;
        liquidationThresholds[2] = liqTresh;

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSCR: LENGTH_MISMATCH");
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();

        baseCurrencies = new uint256[](2);
        baseCurrencies[0] = Constants.UsdBaseCurrency;
        baseCurrencies[1] = Constants.EthBaseCurrency;

        collateralFactors = new uint16[](1);
        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        liquidationThresholds = new uint16[](1);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSCR: LENGTH_MISMATCH");
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testRevert_batchSetRiskVariables_InvalidValue() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory baseCurrencies = new uint256[](2);
        baseCurrencies[0] = Constants.UsdBaseCurrency;
        baseCurrencies[1] = Constants.EthBaseCurrency;

        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = 15000;
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSRV: CollFact not in limits");
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();

        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        liquidationThresholds[0] = 11000;

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSRV: Liq.Thres not in limits");
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testSuccess_batchSetRiskVariables() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory baseCurrencies = new uint256[](2);
        baseCurrencies[0] = Constants.UsdBaseCurrency;
        baseCurrencies[1] = Constants.EthBaseCurrency;

        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();

        vm.startPrank(creatorAddress);
        mainRegistry.batchSetRiskVariables(assetAddresses, baseCurrencies, collateralFactors, liquidationThresholds);
        vm.stopPrank();

        assertEq(
            mainRegistry.DEFAULT_COLLATERAL_FACTOR(),
            mainRegistry.collateralFactors(address(eth), Constants.UsdBaseCurrency)
        );
        assertEq(
            mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD(),
            mainRegistry.liquidationThresholds(address(eth), Constants.EthBaseCurrency)
        );
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
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();
    }

    function testSucccess_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
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
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

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

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdOverflow(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        vm.assume(linkDecimals < Constants.oracleEthToUsdDecimals);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink
                > ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals)
                    / 10 ** (Constants.oracleLinkToUsdDecimals - linkDecimals)
        );

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** linkDecimals),
                assetAddress: address(link)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdWithRateZero(uint256 amountLink)
        public
    {
        vm.assume(amountLink > 0);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(0));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        //Divide by 0
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
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

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
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GTV: Unknown BaseCurrency");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownBaseCurrency() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GLV: Unknown BaseCurrency");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getTotalValue_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GTV: Unknown asset");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GLV: Unknown asset");
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testSuccess_getTotalValue() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

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

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testSuccess_getListOfValuesPerAsset() public {
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

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

        uint256[] memory actualListOfValuesPerAsset =
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

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }
}
