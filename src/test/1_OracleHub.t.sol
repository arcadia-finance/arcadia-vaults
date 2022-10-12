/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../mockups/ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract OracleHubTest is Test {
    using stdStorage for StdStorage;

    ERC20Mock private eth;
    ERC20Mock private snx;
    ERC20Mock private link;

    OracleHub private oracleHub;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;

    address[] public oraclesEthToUsd = new address[](1);
    address[] public oraclesLinkToUsd = new address[](1);
    address[] public oraclesSnxToUsd = new address[](2);
    address[] public oraclesSnxToEth = new address[](1);

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = eth = new ERC20Mock(
            "ETH Mock",
            "mETH",
            uint8(Constants.ethDecimals)
        );
        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleLinkToUsdDecimals), "LINK / USD");
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleSnxToEthDecimals), "SNX / ETH");
    }

    //this is a before each
    function setUp() public {
        vm.prank(creatorAddress);
        oracleHub = new OracleHub();
    }

    function testSuccess_addOracle_Owner(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is less than equal to 1 ether
        vm.assume(oracleEthToUsdUnit <= 10 ** 18);
        vm.startPrank(creatorAddress);
        // When: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );

        // Then: oracleEthToUsd should return true to inOracleHub
        assertTrue(oracleHub.inOracleHub(address(oracleEthToUsd)));
        vm.stopPrank();
    }

    function testRevert_addOracle_OwnerOverwritesOracle() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
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
        // When: creatorAddress addOracle

        // Then: addOracle should revert with "Oracle already in oracle-hub"
        vm.expectRevert("Oracle already in oracle-hub");
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
        vm.stopPrank();
    }

    function testRevert_addOracle_NonOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress
        vm.assume(unprivilegedAddress != creatorAddress);
        // When: unprivilegedAddress addOracle
        vm.startPrank(unprivilegedAddress);
        // Then: addOracle should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.stopPrank();
    }

    function testRevert_addOracle_OwnerAddsOracleBigOracleUnit(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is bigger than 1 ether
        vm.assume(oracleEthToUsdUnit > 10 ** 18);
        // When: creatorAddress addOracle
        vm.startPrank(creatorAddress);
        // Then: addOracle should revert with "Oracle can have maximal 18 decimals"
        vm.expectRevert("Oracle can have maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();
    }

    function testSuccess_checkOracleSequence_SingleOracleToUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
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
        vm.stopPrank();
        // When: oraclesEthToUsd index 0 is oracleEthToUsd
        oraclesEthToUsd[0] = address(oracleEthToUsd);
        // Then: checkOracleSequence should past for oraclesEthToUsd
        oracleHub.checkOracleSequence(oraclesEthToUsd);
    }

    function testSuccess_checkOracleSequence_MultipleOraclesToUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle for ETH-USD and SNX-USD
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
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
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToUsd index 0 is oracleSnxToUsd, oraclesSnxToUsd index 1 is oracleEthToUsd,
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        // Then: checkOracleSequence should past for oraclesSnxToUsd
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testRevert_checkOracleSequence_UnknownOracle() public {
        // Given: oraclesLinkToUsd index 0 equal to
        oraclesLinkToUsd[0] = address(oracleLinkToUsd);
        // When: checkOracleSequence

        // Then: checkOracleSequence with oraclesSnxToUsd should revert with "Unknown oracle"
        vm.expectRevert("Unknown oracle");
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testRevert_checkOracleSequence_NonMatchingBaseAndQuoteAssets() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for SNX-ETH and LINK-USD
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
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
                oracleUnit: uint64(Constants.oracleLinkToUsdDecimals),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToUsd index 0 is oracleSnxToUsd, oraclesSnxToUsd index 1 is oracleLinkToUsd
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleLinkToUsd);
        // Then: checkOracleSequence for oraclesSnxToUsd should revert with "qAsset doesnt match with bAsset of prev oracle"
        vm.expectRevert("qAsset doesnt match with bAsset of prev oracle");
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testRevert_checkOracleSequence_LastBaseAssetNotUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for SNX-ETH
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToEth index 0 is oracleSnxToEth
        oraclesSnxToEth[0] = address(oracleSnxToEth);
        // Then: checkOracleSequence for oraclesSnxToEth should revert with "Last oracle does not have USD as bAsset"
        vm.expectRevert("Last oracle does not have USD as bAsset");
        oracleHub.checkOracleSequence(oraclesSnxToEth);
    }

    function testRevert_checkOracleSequence_MoreThanThreeOracles() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for SNX-ETH
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();
        // When: address 4 is oraclesSequence
        address[] memory oraclesSequence = new address[](4);
        // Then: checkOracleSequence should revert with "Oracle seq. cant be longer than 3"
        vm.expectRevert("Oracle seq. cant be longer than 3");
        oracleHub.checkOracleSequence(oraclesSequence);
    }

    function testSuccess_getRate_BaseCurrencyIsUsdForSingleOracle(uint256 rateEthToUsd, uint8 oracleEthToUsdDecimals)
        public
    {
        // Given: oracleEthToUsdDecimals less than equal to 18, rateEthToUsd less than equal to max uint256 value,
        // rateEthToUsd is less than max uint256 value divided by WAD
        vm.assume(oracleEthToUsdDecimals <= 18);

        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateEthToUsd <= type(uint256).max / Constants.WAD);

        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        // When: creatorAddress addOracle with OracleInformation for ETH-USD, oracleOwner transmit rateEthToUsd
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (Constants.WAD * uint256(rateEthToUsd)) / 10 ** (oracleEthToUsdDecimals);
        uint256 expectedRateInBaseCurrency = 0;

        oraclesEthToUsd[0] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesEthToUsd, Constants.UsdBaseCurrency);

        // Then: actualRateInUsd should be equal to expectedRateInUsd, actualRateInNumeraire should be equal to expectedRateInNumeraire
        assertEq(actualRateInUsd, expectedRateInUsd);
        assertEq(actualRateInBaseCurrency, expectedRateInBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyIsUsdForSingleOracleOverflow(
        uint256 rateEthToUsd,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleEthToUsdDecimals less than equal to 18, rateEthToUsd less than equal to max uint256 value,
        // rateEthToUsd is more than max uint256 value divided by WAD
        vm.assume(oracleEthToUsdDecimals <= 18);

        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateEthToUsd > type(uint256).max / Constants.WAD);

        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        // When: creatorAddress addOracle with OracleInformation for ETH-USD, oracleOwner transmit rateEthToUsd,
        // oraclesEthToUsd index 0 is oracleEthToUsd, oracleOwner getRate
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesEthToUsd[0] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesEthToUsd, Constants.UsdBaseCurrency);
    }

    function testSuccess_getRate_BaseCurrencyIsUsdForMultipleOracles(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is less than equal to uint256 max value divided by WAD
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth <= type(uint256).max / Constants.WAD);

        if (rateSnxToEth == 0) {
            vm.assume(uint256(rateEthToUsd) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(rateEthToUsd)
                    <= type(uint256).max / Constants.WAD * 10 ** oracleSnxToEthDecimals / uint256(rateSnxToEth)
            );
        }

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateSnxToEth)) / 10 ** (oracleSnxToEthDecimals)) * uint256(rateEthToUsd)
        ) / 10 ** (oracleEthToUsdDecimals);
        uint256 expectedRateInBaseCurrency = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);

        // Then: expectedRateInUsd should be equal to actualRateInUsd, expectedRateInNumeraire should be equal to actualRateInNumeraire
        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInBaseCurrency, actualRateInBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyIsUsdForMultipleOraclesOverflow1(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is bigger than uint256 max value divided by WAD
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyIsUsdForMultipleOraclesOverflow2(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal uint256 max value, rateSnxToEth is bigger than 0
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));
        vm.assume(rateSnxToEth > 0);

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        vm.assume(
            uint256(rateEthToUsd)
                > type(uint256).max / Constants.WAD * 10 ** oracleSnxToEthDecimals / uint256(rateSnxToEth)
        );

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);
    }

    function testSuccess_getRate_BaseCurrencyIsUsdForMultipleOraclesFirstRateIsZero(
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is 0
        uint256 rateSnxToEth = 0;

        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateSnxToEth)) / 10 ** (oracleSnxToEthDecimals)) * uint256(rateEthToUsd)
        ) / 10 ** (oracleEthToUsdDecimals);
        uint256 expectedRateInBaseCurrency = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);

        // Then: expectedRateInUsd should be equal to actualRateInUsd, expectedRateInNumeraire should be equal to actualRateInNumeraire
        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInBaseCurrency, actualRateInBaseCurrency);
    }

    function testSuccess_getRate_BaseCurrencyIsNotUsd(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is less than equak to max uint256 value divided by WAD
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = 0;
        uint256 expectedRateInBaseCurrency = (Constants.WAD * uint256(rateSnxToEth) / 10 ** (oracleSnxToEthDecimals));

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesSnxToUsd, Constants.EthBaseCurrency);

        // Then: expectedRateInUsd should be equal to actualRateInUsd, expectedRateInNumeraire should be equal to actualRateInNumeraire
        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInBaseCurrency, actualRateInBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyIsNotUsdOverflow(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is 0
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);
    }

    function testSuccess_getRate_BaseCurrencyIsNotUsdSucces(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is less than equak to max uint256 value divided by WAD
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth <= type(uint256).max / Constants.WAD);

        if (rateSnxToEth == 0) {
            vm.assume(uint256(rateEthToUsd) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(rateEthToUsd)
                    <= type(uint256).max / Constants.WAD * 10 ** oracleSnxToEthDecimals / uint256(rateSnxToEth)
            );
        }

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateSnxToEth)) / 10 ** (oracleSnxToEthDecimals)) * uint256(rateEthToUsd)
        ) / 10 ** (oracleEthToUsdDecimals);
        uint256 expectedRateInBaseCurrency = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesSnxToUsd, Constants.SafemoonBaseCurrency);

        // Then: expectedRateInUsd should be equal to actualRateInUsd, expectedRateInNumeraire should be equal to actualRateInNumeraire
        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInBaseCurrency, actualRateInBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyNotUsd_Overflow1(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);
    }

    function testRevert_getRate_BaseCurrencyNotUsd_Overflow2(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateSnxToEth and rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is bigger than 0
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));
        vm.assume(rateSnxToEth > 0);

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        vm.assume(
            uint256(rateEthToUsd)
                > type(uint256).max / Constants.WAD * 10 ** oracleSnxToEthDecimals / uint256(rateSnxToEth)
        );

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdBaseCurrency);
    }

    function testSuccess_getRate_BaseCurrencyIsNotUsdFirstRateIsZero(
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        // Given: oracleSnxToEthDecimals and oracleEthToUsdDecimals is less than equal to 18,
        // rateEthToUsd is less than equal to uint256 max value, rateSnxToEth is 0
        uint256 rateSnxToEth = 0;

        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        uint64 oracleSnxToEthUnit = uint64(10 ** oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10 ** oracleEthToUsdDecimals);

        // When: creatorAddress addOracle for SNX-ETH and ETH-USD, oracleOwner transmit rateSnxToEth and rateEthToUsd,
        // oraclesSnxToUsd index 0 is oracleSnxToEth, oraclesSnxToUsd index 1 is oracleEthToUsd
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateSnxToEth)) / 10 ** (oracleSnxToEthDecimals)) * uint256(rateEthToUsd)
        ) / 10 ** (oracleEthToUsdDecimals);
        uint256 expectedRateInBaseCurrency = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInBaseCurrency) =
            oracleHub.getRate(oraclesSnxToUsd, Constants.SafemoonBaseCurrency);

        // Then: expectedRateInUsd should be equal to actualRateInUsd, expectedRateInNumeraire should be equal to actualRateInNumeraire
        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInBaseCurrency, actualRateInBaseCurrency);
    }
}
