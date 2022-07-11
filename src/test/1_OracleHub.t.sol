/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../ArcadiaOracle.sol";
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
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

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

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD"
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleLinkToUsdDecimals),
            "LINK / USD"
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleSnxToEthDecimals),
            "SNX / ETH"
        );
    }

    //this is a before each
    function setUp() public {
        vm.prank(creatorAddress);
        oracleHub = new OracleHub();
    }

    function testOwnerAddsOracleSucces(uint64 oracleEthToUsdUnit) public {
        vm.assume(oracleEthToUsdUnit <= 10**18);
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );

        assertTrue(oracleHub.inOracleHub(address(oracleEthToUsd)));
        vm.stopPrank();
    }

    function testOwnerOverwritesOracleFail() public {
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
        vm.expectRevert("Oracle already in oracle-hub");
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
        vm.stopPrank();
    }

    function testNonOwnerAddsOracleFail(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.stopPrank();
    }

    function testOwnerAddsOracleBigOracleUnitFail(uint64 oracleEthToUsdUnit)
        public
    {
        vm.assume(oracleEthToUsdUnit > 10**18);
        vm.startPrank(creatorAddress);
        vm.expectRevert("Oracle can have maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();
    }

    function testCheckOracleSequenceSingleOracleToUsd() public {
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
        vm.stopPrank();
        oraclesEthToUsd[0] = address(oracleEthToUsd);
        oracleHub.checkOracleSequence(oraclesEthToUsd);
    }

    function testCheckOracleSequenceMultipleOraclesToUsd() public {
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
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
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testCheckOracleSequenceUnknownOracle() public {
        oraclesLinkToUsd[0] = address(oracleLinkToUsd);
        vm.expectRevert("Unknown oracle");
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testCheckOracleSequenceNonMatchingBaseAndQuoteAssets() public {
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
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
                oracleUnit: uint64(Constants.oracleLinkToUsdDecimals),
                baseAssetNumeraire: 0,
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();
        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleLinkToUsd);
        vm.expectRevert("qAsset doesnt match with bAsset of prev oracle");
        oracleHub.checkOracleSequence(oraclesSnxToUsd);
    }

    function testCheckOracleSequenceLastBaseAssetNotUsd() public {
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();
        oraclesSnxToEth[0] = address(oracleSnxToEth);
        vm.expectRevert("Last oracle does not have USD as bAsset");
        oracleHub.checkOracleSequence(oraclesSnxToEth);
    }

    function testCheckOracleSequenceMoreThanThreeOracles() public {
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthDecimals),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();
        address[] memory oraclesSequence = new address[](4);
        vm.expectRevert("Oracle seq. cant be longer than 3");
        oracleHub.checkOracleSequence(oraclesSequence);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForSingleOracleSuccess(
        uint256 rateEthToUsd,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleEthToUsdDecimals <= 18);

        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateEthToUsd <= type(uint256).max / Constants.WAD);

        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (Constants.WAD * uint256(rateEthToUsd)) /
            10**(oracleEthToUsdDecimals);
        uint256 expectedRateInNumeraire = 0;

        oraclesEthToUsd[0] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesEthToUsd, Constants.UsdNumeraire);

        assertEq(actualRateInUsd, expectedRateInUsd);
        assertEq(actualRateInNumeraire, expectedRateInNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForSingleOracleOverflow(
        uint256 rateEthToUsd,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleEthToUsdDecimals <= 18);

        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateEthToUsd > type(uint256).max / Constants.WAD);

        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesEthToUsd[0] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesEthToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForMultipleOraclesSucces(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth <= type(uint256).max / Constants.WAD);

        if (rateSnxToEth == 0) {
            vm.assume(
                uint256(rateEthToUsd) <= type(uint256).max / Constants.WAD
            );
        } else {
            vm.assume(
                uint256(rateEthToUsd) <=
                    type(uint256).max /
                        uint256(rateSnxToEth) /
                        10**(18 - oracleSnxToEthDecimals)
            );
        }

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (((Constants.WAD * uint256(rateSnxToEth)) /
            10**(oracleSnxToEthDecimals)) * uint256(rateEthToUsd)) /
            10**(oracleEthToUsdDecimals);
        uint256 expectedRateInNumeraire = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesSnxToUsd, Constants.UsdNumeraire);

        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInNumeraire, actualRateInNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForMultipleOraclesOverflow1(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForMultipleOraclesOverflow2(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));
        vm.assume(rateSnxToEth > 0);

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        vm.assume(
            uint256(rateEthToUsd) >
                (type(uint256).max / uint256(rateSnxToEth) / Constants.WAD) *
                    10**oracleSnxToEthDecimals
        );

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsUsdForMultipleOraclesFirstRateIsZero(
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        uint256 rateSnxToEth = 0;

        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (((Constants.WAD * uint256(rateSnxToEth)) /
            10**(oracleSnxToEthDecimals)) * uint256(rateEthToUsd)) /
            10**(oracleEthToUsdDecimals);
        uint256 expectedRateInNumeraire = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesSnxToUsd, Constants.UsdNumeraire);

        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInNumeraire, actualRateInNumeraire);
    }

    function testReturnNumeraireRateWhenNumeraireIsNotUsdSucces(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = 0;
        uint256 expectedRateInNumeraire = (Constants.WAD *
            uint256(rateSnxToEth)) / 10**(oracleSnxToEthDecimals);

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesSnxToUsd, Constants.EthNumeraire);

        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInNumeraire, actualRateInNumeraire);
    }

    function testReturnNumeraireRateWhenNumeraireIsNotUsdOverflow(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsNotUsdSucces(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(rateSnxToEth <= type(uint256).max / Constants.WAD);

        if (rateSnxToEth == 0) {
            vm.assume(
                uint256(rateEthToUsd) <= type(uint256).max / Constants.WAD
            );
        } else {
            vm.assume(
                uint256(rateEthToUsd) <=
                    (type(uint256).max /
                        uint256(rateSnxToEth) /
                        Constants.WAD) *
                        10**oracleSnxToEthDecimals
            );
        }

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (((Constants.WAD * uint256(rateSnxToEth)) /
            10**(oracleSnxToEthDecimals)) * uint256(rateEthToUsd)) /
            10**(oracleEthToUsdDecimals);
        uint256 expectedRateInNumeraire = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesSnxToUsd, Constants.SafemoonNumeraire);

        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInNumeraire, actualRateInNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsNotUsdOverflow1(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        vm.assume(uint256(rateSnxToEth) > type(uint256).max / Constants.WAD);

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsNotUsdOverflow2(
        uint256 rateSnxToEth,
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);

        vm.assume(rateSnxToEth <= uint256(type(int256).max));
        vm.assume(rateEthToUsd <= uint256(type(int256).max));
        vm.assume(rateSnxToEth > 0);

        vm.assume(uint256(rateSnxToEth) <= type(uint256).max / Constants.WAD);

        vm.assume(
            uint256(rateEthToUsd) >
                (type(uint256).max / uint256(rateSnxToEth) / Constants.WAD) *
                    10**oracleSnxToEthDecimals
        );

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        oracleHub.getRate(oraclesSnxToUsd, Constants.UsdNumeraire);
    }

    function testReturnUsdRateWhenNumeraireIsNotUsdFirstRateIsZero(
        uint256 rateEthToUsd,
        uint8 oracleSnxToEthDecimals,
        uint8 oracleEthToUsdDecimals
    ) public {
        uint256 rateSnxToEth = 0;

        vm.assume(oracleSnxToEthDecimals <= 18 && oracleEthToUsdDecimals <= 18);
        vm.assume(rateEthToUsd <= uint256(type(int256).max));

        uint64 oracleSnxToEthUnit = uint64(10**oracleSnxToEthDecimals);
        uint64 oracleEthToUsdUnit = uint64(10**oracleEthToUsdDecimals);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleSnxToEthUnit,
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
                oracleUnit: oracleEthToUsdUnit,
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (((Constants.WAD * uint256(rateSnxToEth)) /
            10**(oracleSnxToEthDecimals)) * uint256(rateEthToUsd)) /
            10**(oracleEthToUsdDecimals);
        uint256 expectedRateInNumeraire = 0;

        oraclesSnxToUsd[0] = address(oracleSnxToEth);
        oraclesSnxToUsd[1] = address(oracleEthToUsd);
        (uint256 actualRateInUsd, uint256 actualRateInNumeraire) = oracleHub
            .getRate(oraclesSnxToUsd, Constants.SafemoonNumeraire);

        assertEq(expectedRateInUsd, actualRateInUsd);
        assertEq(expectedRateInNumeraire, actualRateInNumeraire);
    }
}
