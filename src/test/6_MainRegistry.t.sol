/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../OracleHub.sol";
import "../Factory.sol";
import "../utils/Constants.sol";
import "../utils/StringHelpers.sol";
import "../utils/CompareArrays.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract MainRegistryTest is Test {
    using stdStorage for StdStorage;

    ERC20Mock private eth;
    ERC20Mock private snx;
    ERC20Mock private link;
    ERC20Mock private safemoon;
    ERC721Mock private bayc;
    ERC721Mock private mayc;
    ERC721Mock private dickButs;
    ERC20Mock private wbayc;
    ERC20Mock private wmayc;
    ERC1155Mock private interleave;
    OracleHub private oracleHub;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;
    ArcadiaOracle private oracleWbaycToEth;
    ArcadiaOracle private oracleWmaycToUsd;
    ArcadiaOracle private oracleInterleaveToEth;
    MainRegistry private mainRegistry;
    StandardERC20Registry private standardERC20Registry;
    FloorERC721SubRegistry private floorERC721SubRegistry;
    FloorERC1155SubRegistry private floorERC1155SubRegistry;
    Factory private factory;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    uint256[] emptyList = new uint256[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);

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

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleLinkToUsdDecimals),
            "LINK / USD",
            rateLinkToUsd
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleSnxToEthDecimals),
            "SNX / ETH",
            rateSnxToEth
        );
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "WBAYC / ETH",
            rateWbaycToEth
        );
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "WBAYC / USD",
            rateWmaycToUsd
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / ETH",
            rateInterleaveToEth
        );

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWbaycToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "WBAYC",
                baseAsset: "ETH",
                oracleAddress: address(oracleWbaycToEth),
                quoteAssetAddress: address(wbayc),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWmaycToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "WMAYC",
                baseAsset: "USD",
                oracleAddress: address(oracleWmaycToUsd),
                quoteAssetAddress: address(wmayc),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleInterleaveToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "INTERLEAVE",
                baseAsset: "ETH",
                oracleAddress: address(oracleInterleaveToEth),
                quoteAssetAddress: address(interleave),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

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
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );

        standardERC20Registry = new StandardERC20Registry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC721SubRegistry = new FloorERC721SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC1155SubRegistry = new FloorERC1155SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        vm.stopPrank();
    }

    function testMainRegistryInitialisedWithUsdAsNumeraire() public {
        (, , , , , string memory numeraireLabel) = mainRegistry
            .numeraireToInformation(0);
        assertTrue(StringHelpers.compareStrings("USD", numeraireLabel));
    }

    function testMainRegistryInitialisedWithNumeraireCounterOfZero() public {
        assertEq(1, mainRegistry.numeraireCounter());
    }

    function testNonOwnerAddsNumeraire(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        vm.stopPrank();
    }

    function testOwnerAddsNumeraireWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );

        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AN: lenght");
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerAddsNumeraireWithNonExistingCreditRatingCategory()
        public
    {
        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = mainRegistry.CREDIT_RATING_CATOGERIES();
        assetCreditRatings[1] = 0;
        vm.expectRevert("MR_AN: non existing credRat");
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerAddsNumeraireWithEmptyListOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );

        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        vm.stopPrank();

        assertEq(2, mainRegistry.numeraireCounter());
    }

    function testOwnerAddsNumeraireWithFullListOfCreditRatings() public {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;

        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );

        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            assetCreditRatings
        );
        vm.stopPrank();

        assertEq(2, mainRegistry.numeraireCounter());
    }

    function testNonOwnerAddsSubRegistry(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();
    }

    function testOwnerAddsSubRegistry() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();

        assertTrue(mainRegistry.isSubRegistry(address(standardERC20Registry)));
    }

    function testOwnerOverwritesSubRegistry() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.expectRevert("Sub-Registry already exists");
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();
    }

    function testAssetUpgradabilityDefaultTrue() public {
        assertTrue(mainRegistry.assetsUpdatable());
    }

    function testNonOwnerSetsAssetsToNonUpdatable(address unprivilegedAddress)
        public
    {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();
    }

    function testOwnerSetsAssetsToNonUpdatable() public {
        vm.startPrank(creatorAddress);
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        assertTrue(!mainRegistry.assetsUpdatable());
    }

    function testNonSubregistryAddsAsset(address unprivilegedAddress) public {
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Caller is not a sub-registry.");
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();
    }

    function testSubregistryAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();

        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;

        vm.startPrank(address(standardERC20Registry));
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        mainRegistry.addAsset(address(eth), assetCreditRatings);
        vm.stopPrank();
    }

    function testSubregistryAddsAssetWithNonExistingCreditRatingCategory()
        public
    {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = mainRegistry.CREDIT_RATING_CATOGERIES();
        assetCreditRatings[1] = 0;

        vm.startPrank(address(standardERC20Registry));
        vm.expectRevert("MR_AA: non-existing");
        mainRegistry.addAsset(address(eth), assetCreditRatings);
        vm.stopPrank();
    }

    function testSubregistryAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();

        vm.startPrank(address(standardERC20Registry));
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();

        assertTrue(mainRegistry.inMainRegistry(address(eth)));
    }

    function testSubregistryAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        vm.stopPrank();

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;

        vm.startPrank(address(standardERC20Registry));
        mainRegistry.addAsset(address(eth), assetCreditRatings);
        vm.stopPrank();

        assertTrue(mainRegistry.inMainRegistry(address(eth)));
    }

    function testSubregistryOverwritesAssetPositive() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        vm.stopPrank();

        vm.startPrank(address(standardERC20Registry));
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();

        assertEq(
            address(standardERC20Registry),
            mainRegistry.assetToSubRegistry(address(eth))
        );

        vm.startPrank(address(floorERC721SubRegistry));
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();

        assertEq(
            address(floorERC721SubRegistry),
            mainRegistry.assetToSubRegistry(address(eth))
        );
    }

    function testSubregistryOverwritesAssetNegative() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        mainRegistry.setAssetsToNonUpdatable();
        vm.stopPrank();

        vm.startPrank(address(standardERC20Registry));
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();

        assertEq(
            address(standardERC20Registry),
            mainRegistry.assetToSubRegistry(address(eth))
        );

        vm.startPrank(address(floorERC721SubRegistry));
        vm.expectRevert("MR_AA: already known");
        mainRegistry.addAsset(address(eth), emptyList);
        vm.stopPrank();

        assertEq(
            address(standardERC20Registry),
            mainRegistry.assetToSubRegistry(address(eth))
        );
    }

    function testIsBatchWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
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

    function testIsBatchWhitelistedNegativeNonEqualInputLists() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
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

    function testIsBatchWhitelistedNegativeAssetNotWhitelisted() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyList
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

    function testIsBatchWhitelistedNegativeAssetNotInMainregistry() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyList
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

    function testGetWhitelistWithMultipleAssets() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(
            CompareArrays.compareArrays(expectedWhiteList, actualWhiteList)
        );
    }

    function testGetWhitelistWithAfterRemovalOfAsset() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        standardERC20Registry.removeFromWhiteList(address(snx));
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(
            CompareArrays.compareArrays(expectedWhiteList, actualWhiteList)
        );
    }

    function testGetWhitelistWithAfterRemovalAndReaddingOfAsset() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        standardERC20Registry.removeFromWhiteList(address(snx));
        standardERC20Registry.addToWhiteList(address(snx));
        vm.stopPrank();

        address[] memory expectedWhiteList = new address[](3);
        expectedWhiteList[0] = address(eth);
        expectedWhiteList[1] = address(snx);
        expectedWhiteList[2] = address(bayc);

        address[] memory actualWhiteList = mainRegistry.getWhiteList();
        assertTrue(
            CompareArrays.compareArrays(expectedWhiteList, actualWhiteList)
        );
    }

    function testGetTotalValueCalculateValueInNumeraireFromValueInUsdSucces(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        vm.assume(linkDecimals <= 18);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink <=
                type(uint256).max /
                    uint256(rateLinkToUsd) /
                    Constants.WAD /
                    10 **
                        (Constants.oracleEthToUsdDecimals -
                            Constants.oracleLinkToUsdDecimals)
        );
        vm.assume(
            amountLink <=
                (((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) *
                    10**Constants.oracleEthToUsdDecimals) /
                    10**Constants.oracleLinkToUsdDecimals) *
                    10**linkDecimals
        );

        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
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

        uint256 actualTotalValue = mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.EthNumeraire
        );

        uint256 linkValueInUsd = (assetAmounts[0] *
            rateLinkToUsd *
            Constants.WAD) /
            10**Constants.oracleLinkToUsdDecimals /
            10**linkDecimals;
        uint256 linkValueInEth = (linkValueInUsd *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsdNew;

        uint256 expectedTotalValue = linkValueInEth;

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testGetTotalValueCalculateValueInNumeraireFromValueInUsdOverflow(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        vm.assume(linkDecimals < Constants.oracleEthToUsdDecimals);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink >
                ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) *
                    10**Constants.oracleEthToUsdDecimals) /
                    10**(Constants.oracleLinkToUsdDecimals - linkDecimals)
        );

        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
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
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.EthNumeraire
        );
    }

    function testGetTotalValueCalculateValueInNumeraireFromValueInUsdWithRateZero(
        uint256 amountLink
    ) public {
        vm.assume(amountLink > 0);

        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        vm.stopPrank();

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
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.EthNumeraire
        );
    }

    function testGetTotalValueNegativeNonEqualInputLists() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GTV: LENGTH_MISMATCH");
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 10;

        vm.expectRevert("MR_GTV: LENGTH_MISMATCH");
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );
    }

    function testGetListOfValuesPerAssetNegativeNonEqualInputLists() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GLV: LENGTH_MISMATCH");
        mainRegistry.getListOfValuesPerAsset(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 10;

        vm.expectRevert("MR_GLV: LENGTH_MISMATCH");
        mainRegistry.getListOfValuesPerAsset(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );
    }

    function testGetTotalValueNegativeUnknownNumeraire() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GTV: Unknown Numeraire");
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.SafemoonNumeraire
        );
    }

    function testGetListOfValuesPerAsseteNegativeUnknownNumeraire() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GLV: Unknown Numeraire");
        mainRegistry.getListOfValuesPerAsset(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.SafemoonNumeraire
        );
    }

    function testGetTotalValueNegativeUnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

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
        mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );
    }

    function testGetListOfValuesPerAsseteNegativeUnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

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
        mainRegistry.getListOfValuesPerAsset(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.UsdNumeraire
        );
    }

    function testGetTotalValueSucces() public {
        //Does not test on overflow, test to check if function correctly returns value in Numeraire or USD
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

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
        assetAmounts[0] = 10**Constants.ethDecimals;
        assetAmounts[1] = 10**Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256 actualTotalValue = mainRegistry.getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            Constants.EthNumeraire
        );

        uint256 ethValueInEth = (Constants.WAD * assetAmounts[0]) /
            10**Constants.ethDecimals;
        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            assetAmounts[1]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;
        uint256 baycValueInEth = (Constants.WAD *
            rateWbaycToEth *
            assetAmounts[2]) / 10**Constants.oracleWbaycToEthDecimals;

        uint256 expectedTotalValue = ethValueInEth +
            linkValueInEth +
            baycValueInEth;

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testGetListOfValuesPerAssetSucces() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

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
        assetAmounts[0] = 10**Constants.ethDecimals;
        assetAmounts[1] = 10**Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256[] memory actualListOfValuesPerAsset = mainRegistry
            .getListOfValuesPerAsset(
                assetAddresses,
                assetIds,
                assetAmounts,
                Constants.EthNumeraire
            );

        uint256 ethValueInEth = (Constants.WAD * assetAmounts[0]) /
            10**Constants.ethDecimals;
        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            assetAmounts[1]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;
        uint256 baycValueInEth = (Constants.WAD *
            rateWbaycToEth *
            assetAmounts[2]) / 10**Constants.oracleWbaycToEthDecimals;

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = ethValueInEth;
        expectedListOfValuesPerAsset[1] = linkValueInEth;
        expectedListOfValuesPerAsset[2] = baycValueInEth;

        assertTrue(
            CompareArrays.compareArrays(
                expectedListOfValuesPerAsset,
                actualListOfValuesPerAsset
            )
        );
    }

    function testGetListOfValuesPerCreditRatingSucces() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        assetCreditRatings[0] = Constants.linkCreditRatingUsd;
        assetCreditRatings[1] = Constants.linkCreditRatingEth;
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatings
        );

        assetCreditRatings[0] = Constants.baycCreditRatingUsd;
        assetCreditRatings[1] = Constants.baycCreditRatingEth;
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );
        vm.stopPrank();

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
        assetAmounts[0] = 10**Constants.ethDecimals;
        assetAmounts[1] = 10**Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256[] memory actualListOfValuesPerCreditRating = mainRegistry
            .getListOfValuesPerCreditRating(
                assetAddresses,
                assetIds,
                assetAmounts,
                Constants.EthNumeraire
            );

        uint256 ethValueInEth = (Constants.WAD * assetAmounts[0]) /
            10**Constants.ethDecimals;
        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            assetAmounts[1]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;
        uint256 baycValueInEth = (Constants.WAD *
            rateWbaycToEth *
            assetAmounts[2]) / 10**Constants.oracleWbaycToEthDecimals;

        uint256[] memory expectedListOfValuesPerCreditRating = new uint256[](
            mainRegistry.CREDIT_RATING_CATOGERIES()
        );
        expectedListOfValuesPerCreditRating[
            Constants.ethCreditRatingEth
        ] += ethValueInEth;
        expectedListOfValuesPerCreditRating[
            Constants.linkCreditRatingEth
        ] += linkValueInEth;
        expectedListOfValuesPerCreditRating[
            Constants.baycCreditRatingEth
        ] += baycValueInEth;

        assertTrue(
            CompareArrays.compareArrays(
                actualListOfValuesPerCreditRating,
                expectedListOfValuesPerCreditRating
            )
        );
    }

    function testNonOwnerSetsCreditRatings(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory numeraires = new uint256[](2);
        numeraires[0] = Constants.UsdNumeraire;
        numeraires[1] = Constants.EthNumeraire;

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.batchSetCreditRating(
            assetAddresses,
            numeraires,
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerSetsCreditRatingsNonEqualInputLists() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory numeraires = new uint256[](1);
        numeraires[0] = Constants.UsdNumeraire;

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSCR: LENGTH_MISMATCH");
        mainRegistry.batchSetCreditRating(
            assetAddresses,
            numeraires,
            assetCreditRatings
        );
        vm.stopPrank();

        numeraires = new uint256[](2);
        numeraires[0] = Constants.UsdNumeraire;
        numeraires[1] = Constants.EthNumeraire;

        assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSCR: LENGTH_MISMATCH");
        mainRegistry.batchSetCreditRating(
            assetAddresses,
            numeraires,
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerSetsCreditRatingsSucces() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory numeraires = new uint256[](2);
        numeraires[0] = Constants.UsdNumeraire;
        numeraires[1] = Constants.EthNumeraire;

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.startPrank(creatorAddress);
        mainRegistry.batchSetCreditRating(
            assetAddresses,
            numeraires,
            assetCreditRatings
        );
        vm.stopPrank();

        assertEq(
            Constants.ethCreditRatingUsd,
            mainRegistry.assetToNumeraireToCreditRating(
                address(eth),
                Constants.UsdNumeraire
            )
        );
        assertEq(
            Constants.ethCreditRatingEth,
            mainRegistry.assetToNumeraireToCreditRating(
                address(eth),
                Constants.EthNumeraire
            )
        );
    }

    function testOwnerSetsCreditRatingsWithNonExistingCreditRatingCategory()
        public
    {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(eth);

        uint256[] memory numeraires = new uint256[](2);
        numeraires[0] = Constants.UsdNumeraire;
        numeraires[1] = Constants.EthNumeraire;

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = mainRegistry.CREDIT_RATING_CATOGERIES();
        assetCreditRatings[1] = mainRegistry.CREDIT_RATING_CATOGERIES();

        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_BSCR: non-existing creditRat");
        mainRegistry.batchSetCreditRating(
            assetAddresses,
            numeraires,
            assetCreditRatings
        );
        vm.stopPrank();
    }

    //Test setFactory
    function testNonOwnerSetsFactory(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    function testMainRegistryNotSetInFactory() public {
        vm.startPrank(creatorAddress);
        factory = new Factory();
        vm.expectRevert("MR_AA: MR not set in factory");
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    function testMainRegistryNotConfirmedInFactory() public {
        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.expectRevert("MR_AA: MR not set in factory");
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    function testOwnerSetsFactoryWithMultipleNumeraires() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        factory.confirmNewVaultInfo();
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

        assertEq(address(factory), mainRegistry.factoryAddress());
    }
}
