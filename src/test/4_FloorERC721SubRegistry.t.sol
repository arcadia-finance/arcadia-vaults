/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract FloorERC721SubRegistryTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    ERC721Mock private bayc;
    ERC721Mock private mayc;
    ERC20Mock private wbayc;
    ERC20Mock private wmayc;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleWbaycToEth;
    ArcadiaOracle private oracleWmaycToUsd;

    FloorERC721SubRegistry private floorERC721SubRegistry;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;

    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);

    uint256[] emptyList = new uint256[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        bayc = new ERC721Mock("BAYC Mock", "mBAYC");
        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        vm.stopPrank();

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
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "LINK / USD",
            rateWbaycToEth
        );
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "SNX / ETH",
            rateWmaycToUsd
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
        vm.stopPrank();

        oracleWbaycToEthEthToUsd[0] = address(oracleWbaycToEth);
        oracleWbaycToEthEthToUsd[1] = address(oracleEthToUsd);

        oracleWmaycToUsdArr[0] = address(oracleWmaycToUsd);
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

        floorERC721SubRegistry = new FloorERC721SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        vm.stopPrank();
    }

    function testNonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
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
    }

    function testOwnerAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
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
    }

    function testOwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
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

        assertTrue(floorERC721SubRegistry.inSubRegistry(address(bayc)));
    }

    function testOwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
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

        assertTrue(floorERC721SubRegistry.inSubRegistry(address(bayc)));
    }

    function testOwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
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

        assertTrue(floorERC721SubRegistry.inSubRegistry(address(bayc)));
    }

    function testIsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
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

        assertTrue(floorERC721SubRegistry.isWhiteListed(address(bayc), 0));
        assertTrue(floorERC721SubRegistry.isWhiteListed(address(bayc), 9999));
        assertTrue(floorERC721SubRegistry.isWhiteListed(address(bayc), 5000));
    }

    function testIsWhitelistedNegativeWrongAddress(address randomAsset) public {
        assertTrue(!floorERC721SubRegistry.isWhiteListed(randomAsset, 0));
    }

    function testIsWhitelistedNegativeIdOutsideRange(uint256 id) public {
        vm.assume(id < 10 || id > 1000);
        vm.startPrank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 10,
                idRangeEnd: 999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(!floorERC721SubRegistry.isWhiteListed(address(bayc), id));
    }

    function testReturnUsdValueWhenNumeraireIsUsd() public {
        vm.startPrank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (rateWbaycToEth *
            rateEthToUsd *
            Constants.WAD) /
            10 **
                (Constants.oracleWbaycToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInNumeraire = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(bayc),
                assetId: 0,
                assetAmount: 1,
                numeraire: 0
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInNumeraire
        ) = floorERC721SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInNumeraire, expectedValueInNumeraire);
    }

    function testreturnNumeraireValueWhenNumeraireIsNotUsd() public {
        vm.startPrank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 999,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInNumeraire = (rateWbaycToEth * Constants.WAD) /
            10**Constants.oracleWbaycToEthDecimals;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(bayc),
                assetId: 0,
                assetAmount: 1,
                numeraire: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInNumeraire
        ) = floorERC721SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInNumeraire, expectedValueInNumeraire);
    }

    function testReturnUsdValueWhenNumeraireIsNotUsd() public {
        vm.startPrank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWmaycToUsdArr,
                idRangeStart: 0,
                idRangeEnd: 999,
                assetAddress: address(mayc)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (rateWmaycToUsd * Constants.WAD) /
            10**Constants.oracleWmaycToUsdDecimals;
        uint256 expectedValueInNumeraire = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(mayc),
                assetId: 0,
                assetAmount: 1,
                numeraire: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInNumeraire
        ) = floorERC721SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInNumeraire, expectedValueInNumeraire);
    }
}
