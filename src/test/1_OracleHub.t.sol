/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../mockups/ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract RevertingOracle {
    function latestRoundData() public pure returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}

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

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_addOracle_Owner(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is less than equal to 1 ether
        vm.assume(oracleEthToUsdUnit <= 10 ** 18);
        // When: creatorAddress addOracle with OracleInformation
        vm.prank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        // Then: oracleEthToUsd should return true to inOracleHub
        assertTrue(oracleHub.inOracleHub(address(oracleEthToUsd)));
        (
            bool isActive,
            uint64 oracleUnit,
            uint8 quoteAssetBaseCurrency,
            bool quoteAssetIsBaseCurrency,
            ,
            address baseAssetAddress,
            bytes16 baseAsset,
            bytes16 quoteAsset
        ) = oracleHub.oracleToOracleInformation(address(oracleEthToUsd));
        assertEq(oracleUnit, oracleEthToUsdUnit);
        assertEq(quoteAssetBaseCurrency, uint8(Constants.UsdBaseCurrency));
        assertEq(quoteAssetIsBaseCurrency, true);
        assertEq(baseAsset, bytes16(abi.encodePacked("ETH")));
        assertEq(quoteAsset, bytes16(abi.encodePacked("USD")));
        assertEq(baseAssetAddress, address(eth));
        assertEq(isActive, true);
    }

    function testRevert_addOracle_OverwriteOracle() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        // When: creatorAddress addOracle

        // Then: addOracle should revert with "OH_AO: Oracle not unique"
        vm.expectRevert("OH_AO: Oracle not unique");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
    }

    function testRevert_addOracle_NonOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress
        vm.assume(unprivilegedAddress != creatorAddress);
        // When: unprivilegedAddress addOracle
        vm.startPrank(unprivilegedAddress);
        // Then: addOracle should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
    }

    function testRevert_addOracle_BigOracleUnit(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is bigger than 1 ether
        vm.assume(oracleEthToUsdUnit > 10 ** 18);
        // When: creatorAddress addOracle
        vm.startPrank(creatorAddress);
        // Then: addOracle should revert with "OH_AO: Maximal 18 decimals"
        vm.expectRevert("OH_AO: Maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oraclesEthToUsd index 0 is oracleEthToUsd
        oraclesEthToUsd[0] = address(oracleEthToUsd);
        // Then: checkOracleSequence should past for oraclesEthToUsd
        oracleHub.checkOracleSequence(oraclesEthToUsd, address(eth));
    }

    function testSuccess_checkOracleSequence_MultipleOraclesToUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle for ETH-USD and SNX-USD
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToUsd index 0 is oracleSnxToUsd, oraclesSnxToUsd index 1 is oracleEthToUsd,
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        // Then: checkOracleSequence should past for oraclesSnxToUsd
        oracleHub.checkOracleSequence(oraclesSnxToUsd, address(snx));
    }

    function testRevert_checkOracleSequence_ZeroOracles() public {
        // When: address 4 is oraclesSequence
        address[] memory oraclesSequence = new address[](0);
        // Then: checkOracleSequence should revert with "OH_COS: Max 3 Oracles"
        vm.expectRevert("OH_COS: Min 1 Oracle");
        oracleHub.checkOracleSequence(oraclesSequence, address(eth));
    }

    function testRevert_checkOracleSequence_MoreThanThreeOracles() public {
        // When: address 4 is oraclesSequence
        address[] memory oraclesSequence = new address[](4);
        // Then: checkOracleSequence should revert with "OH_COS: Max 3 Oracles"
        vm.expectRevert("OH_COS: Max 3 Oracles");
        oracleHub.checkOracleSequence(oraclesSequence, address(eth));
    }

    function testRevert_checkOracleSequence_UnknownOracle() public {
        // When: checkOracleSequence

        // Then: checkOracleSequence with oraclesSnxToUsd should revert with "OH_COS: Unknown Oracle"
        vm.expectRevert("OH_COS: Oracle not active");
        oracleHub.checkOracleSequence(oraclesSnxToUsd, address(snx));
    }

    function testRevert_checkOracleSequence_InactiveOracle() public {
        vm.prank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(0); // Lower than min value

        oracleHub.decommissionOracle(address(oracleEthToUsd));

        // Then: checkOracleSequence with oraclesSnxToUsd should revert with "OH_COS: Unknown Oracle"
        vm.expectRevert("OH_COS: Oracle not active");
        oracleHub.checkOracleSequence(oraclesEthToUsd, address(eth));
    }

    function testRevert_checkOracleSequence_NonMatchingFirstQuoteAssets(address asset) public {
        vm.assume(asset != address(eth));
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oraclesEthToUsd index 0 is oracleEthToUsd
        oraclesEthToUsd[0] = address(oracleEthToUsd);

        // Then: checkOracleSequence with oraclesSnxToUsd should revert with "OH_COS: Unknown Oracle"
        vm.expectRevert("OH_COS: No Match First bAsset");
        oracleHub.checkOracleSequence(oraclesEthToUsd, asset);
    }

    function testRevert_checkOracleSequence_NonMatchingBaseAndQuoteAssets() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for SNX-ETH and LINK-USD
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdDecimals),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "LINK",
                quoteAsset: "USD",
                oracle: address(oracleLinkToUsd),
                baseAssetAddress: address(link),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToUsd index 0 is oracleSnxToUsd, oraclesSnxToUsd index 1 is oracleLinkToUsd
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleLinkToUsd);
        // Then: checkOracleSequence for oraclesSnxToUsd should revert with "OH_COS: No Match bAsset and qAsset"
        vm.expectRevert("OH_COS: No Match bAsset and qAsset");
        oracleHub.checkOracleSequence(oraclesSnxToUsd, address(snx));
    }

    function testRevert_checkOracleSequence_LastBaseAssetNotUsd() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for SNX-ETH
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oraclesSnxToEth index 0 is oracleSnxToEth
        oraclesSnxToEth[0] = address(oracleSnxToEth);
        // Then: checkOracleSequence for oraclesSnxToEth should revert with "OH_COS: Last qAsset not USD"
        vm.expectRevert("OH_COS: Last qAsset not USD");
        oracleHub.checkOracleSequence(oraclesSnxToEth, address(snx));
    }

    function testSuccess_isActive_negative(address oracle) public {
        assertFalse(oracleHub.isActive(address(oracle)));
    }

    function testSuccess_isActive_positive() public {
        vm.prank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        assertTrue(oracleHub.isActive(address(oracleEthToUsd)));
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testRevert_getRate_NegativeRate(int256 rateEthToUsd) public {
        // Given: oracleEthToUsdDecimals less than equal to 18, rateEthToUsd less than equal to max uint256 value,
        // rateEthToUsd is less than max uint256 value divided by WAD
        vm.assume(rateEthToUsd < 0);

        vm.startPrank(creatorAddress);
        // When: creatorAddress addOracle with OracleInformation for ETH-USD, oracleOwner transmit rateEthToUsd
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(rateEthToUsd);
        vm.stopPrank();

        oraclesEthToUsd[0] = address(oracleEthToUsd);

        vm.expectRevert("OH_GR: Negative Rate");
        oracleHub.getRate(oraclesEthToUsd, Constants.UsdBaseCurrency);
    }

    function testRevert_getRate_NoUsdOrBaseCurrencyOracle() public {
        vm.expectRevert("OH_GR: No qAsset in USD or bCurr");
        oracleHub.getRate(new address[](0), Constants.UsdBaseCurrency);
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
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
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

    //
    //Oracle failsafe tests
    //
    function testRevert_decommissionOracle_notInHub(address sender, address oracle) public {
        vm.assume(oracle != address(oracleEthToUsd));
        vm.assume(oracle != address(oracleLinkToUsd));
        vm.assume(oracle != address(oracleSnxToEth));

        vm.startPrank(sender);
        vm.expectRevert("OH_DO: Oracle not in Hub");
        oracleHub.decommissionOracle(oracle);
        vm.stopPrank();
    }

    function testSuccess_decommissionOracle_NonExistingContract(address sender) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "REVERT",
                quoteAsset: "USD",
                oracle: address(revertingOracle),
                baseAssetAddress: address(0),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        vm.prank(sender);
        oracleHub.decommissionOracle(address(revertingOracle));

        (bool isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(revertingOracle));
        assertEq(isActive, false);

        address[] memory oracles = new address[](1);
        oracles[0] = address(revertingOracle);

        (uint256 rateInUsd, uint256 rateInBaseCurrency) = oracleHub.getRate(oracles, Constants.UsdBaseCurrency);

        assertEq(rateInUsd, 0);
        assertEq(rateInBaseCurrency, 0);
    }

    function testSuccess_decommissionOracle_answerTooLow(address sender) public {
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(oracleOwner);
        //minAnswer is set to 100 in the oracle mocks
        oracleSnxToEth.transmit(int256(1));
        oracleEthToUsd.transmit(int256(500_000_000_000));
        vm.stopPrank();

        (bool isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, true);

        vm.prank(sender);
        oracleHub.decommissionOracle(address(oracleSnxToEth));

        (isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(oracleSnxToEth);
        oracles[1] = address(oracleEthToUsd);

        (uint256 rateInUsd, uint256 rateInBaseCurrency) = oracleHub.getRate(oracles, Constants.UsdBaseCurrency);

        assertEq(rateInUsd, 0);
        assertEq(rateInBaseCurrency, 0);
    }

    function testSuccess_decommissionOracle_updatedAtTooOld(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(oracleOwner);
        //minAnswer is set to 100 in the oracle mocks
        oracleSnxToEth.transmit(int256(500_000_000_000));
        oracleEthToUsd.transmit(int256(500_000_000_000));
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, true);

        vm.prank(sender);
        oracleHub.decommissionOracle(address(oracleSnxToEth));

        (isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(oracleSnxToEth);
        oracles[1] = address(oracleEthToUsd);

        (uint256 rateInUsd, uint256 rateInBaseCurrency) = oracleHub.getRate(oracles, Constants.UsdBaseCurrency);

        assertEq(rateInUsd, 0);
        assertEq(rateInBaseCurrency, 0);
    }

    function testSuccess_decommissionOracle_resetOralceInUse(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "SNX",
                quoteAsset: "ETH",
                oracle: address(oracleSnxToEth),
                baseAssetAddress: address(snx),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                quoteAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracleEthToUsd),
                baseAssetAddress: address(eth),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(oracleOwner);
        //minAnswer is set to 100 in the oracle mocks
        oracleSnxToEth.transmit(int256(500_000_000_000));
        oracleEthToUsd.transmit(int256(500_000_000_000)); //only one of the two is needed to fail
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, true);

        vm.prank(sender);
        oracleHub.decommissionOracle(address(oracleSnxToEth));

        (isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(oracleSnxToEth);
        oracles[1] = address(oracleEthToUsd);

        (uint256 rateInUsd, uint256 rateInBaseCurrency) = oracleHub.getRate(oracles, Constants.UsdBaseCurrency);

        assertEq(rateInUsd, 0);
        assertEq(rateInBaseCurrency, 0);

        vm.startPrank(oracleOwner);
        //minAnswer is set to 100 in the oracle mocks
        oracleSnxToEth.transmit(int256(500_000_000_000));
        oracleEthToUsd.transmit(int256(500_000_000_000)); //only one of the two is needed to fail
        vm.stopPrank();

        vm.prank(sender);
        oracleHub.decommissionOracle(address(oracleSnxToEth));

        (isActive,,,,,,,) = oracleHub.oracleToOracleInformation(address(oracleSnxToEth));
        assertEq(isActive, true);

        oracles = new address[](2);
        oracles[0] = address(oracleSnxToEth);
        oracles[1] = address(oracleEthToUsd);

        (rateInUsd, rateInBaseCurrency) = oracleHub.getRate(oracles, Constants.UsdBaseCurrency);

        assertEq(rateInUsd, 250_000);
    }
}
