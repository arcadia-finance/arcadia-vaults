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
import "../AssetRegistry/aTokenSubRegistry.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract aTokenSubRegistryTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private aEth;
    ERC20Mock private aLink;
    ERC20Mock private aSnx;
    ERC20Mock private eth;
    ERC20Mock private link;
    ERC20Mock private snx;

    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;

    ATokenSubRegistry private aTokenSubRegistry;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 1850 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;

    address[] public oracleAEthToUsdArr = new address[](1);
    address[] public oracleALinkToUsdArr = new address[](1);
    address[] public oracleASnxToEthEthToUsd = new address[](2);

    uint256[] emptyList = new uint256[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        link = new ERC20Mock("LINK Mock", "mLink", uint8(Constants.linkDecimals));
        aEth = new ERC20Mock("aETH Mock", "maETH", uint8(Constants.ethDecimals));
        aLink = new ERC20Mock("aLink Mock", "maLink", uint8(Constants.linkDecimals));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnit: 1
            })
        );
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "LINK / USD",
            rateLinkToUsd
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "SNX / ETH",
            rateSnxToEth
        );

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit), //Should be same right?
                baseAssetBaseCurrency: 0,
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
                baseAssetBaseCurrency: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        oracleAEthToUsdArr[0] = address(oracleEthToUsd);
        oracleALinkToUsdArr[0] = address(oracleLinkToUsd);
        oracleASnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleASnxToEthEthToUsd[1] = address(oracleEthToUsd);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnit: 1
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );

        aTokenSubRegistry = new ATokenSubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(aTokenSubRegistry));
        vm.stopPrank();
    }

    function testNonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        aTokenSubRegistry.setAssetInformation(
            ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithMoreThan18Decimals() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        emit log_named_uint("acrLength", assetCreditRatings.length);
        emit log_named_uint("baseCurrencyCounter", mainRegistry.baseCurrencyCounter());
        vm.expectRevert("ASR_SAI: Maximal 18 decimals");
        aTokenSubRegistry.setAssetInformation(
        ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**19),
                assetAddress: address(aEth)
            }),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
                aTokenSubRegistry.setAssetInformation(
                ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
            ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(aTokenSubRegistry.inSubRegistry(address(aEth)));
    }

    function testOwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        aTokenSubRegistry.setAssetInformation(
            ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            assetCreditRatings
        );
        vm.stopPrank();

        assertTrue(aTokenSubRegistry.inSubRegistry(address(aEth)));
    }

    function testOwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
            ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        aTokenSubRegistry.setAssetInformation(
            ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(aTokenSubRegistry.inSubRegistry(address(aEth)));
    }

    function testIsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
           ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(aTokenSubRegistry.isWhiteListed(address(aEth), 0));
    }

    function testIsWhitelistedNegative(address randomAsset) public {
        assertTrue(!aTokenSubRegistry.isWhiteListed(randomAsset, 0));
    }

    function testReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
         ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountEth *
            rateEthToUsd *
            Constants.WAD) /
            10**(Constants.oracleEthToUsdDecimals + Constants.ethDecimals);
        uint256 expectedValueInBaseCurrency = 0;


        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(aEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });

        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = aTokenSubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(uint128 amountSnx)
        public
    {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
         ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(snx),
                underlyingAssetOracleAddresses: oracleASnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(aSnx)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (amountSnx *
            rateSnxToEth *
            Constants.WAD) /
            10**(Constants.oracleSnxToEthDecimals + Constants.snxDecimals);

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(aSnx),
                assetId: 0,
                assetAmount: amountSnx,
                baseCurrency: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = aTokenSubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountLink)
        public
    {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
         ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(link),
                underlyingAssetOracleAddresses: oracleALinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(aLink)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountLink *
            rateLinkToUsd *
            Constants.WAD) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(aLink),
                assetId: 0,
                assetAmount: amountLink,
                baseCurrency: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = aTokenSubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueSucces(uint256 rateEthToUsdNew, uint256 amountEth)
        public
    {
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);

        if (rateEthToUsdNew == 0) {
            vm.assume(uint256(amountEth) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountEth) <=
                    type(uint256).max / 
                        Constants.WAD *
                        10**Constants.oracleEthToUsdDecimals /
                        uint256(rateEthToUsdNew)
            );
        }

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
                  ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (((Constants.WAD * rateEthToUsdNew) /
            10**Constants.oracleEthToUsdDecimals) * amountEth) /
            10**Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(aEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = aTokenSubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueOverflow(uint256 rateEthToUsdNew, uint256 amountEth)
        public
    {
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateEthToUsdNew > 0);

        vm.assume(
            uint256(amountEth) >
                type(uint256).max / 
                    Constants.WAD *
                    10**Constants.oracleEthToUsdDecimals /
                    uint256(rateEthToUsdNew)
        );

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        aTokenSubRegistry.setAssetInformation(
               ATokenSubRegistry.AssetInformation({
                underlyingAssetAddress: address(eth),
                underlyingAssetOracleAddresses: oracleAEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(aEth)
            }),
            emptyList
        );
        vm.stopPrank();

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(aEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });
        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        aTokenSubRegistry.getValue(getValueInput);
    }
}
