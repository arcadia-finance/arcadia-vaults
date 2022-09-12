/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract FloorERC1155SubRegistryTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    ERC1155Mock private interleave;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleInterleaveToEth;

    FloorERC1155SubRegistry private floorERC1155SubRegistry;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    uint256[] emptyList = new uint256[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
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
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / USD",
            rateInterleaveToEth
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

        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
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
                baseCurrencyLabel: "ETH",
                baseCurrencyUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );

        floorERC1155SubRegistry = new FloorERC1155SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(floorERC1155SubRegistry));
        vm.stopPrank();
    }

    function testNonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
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
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            assetCreditRatings
        );

        vm.stopPrank();
    }

    function testOwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(floorERC1155SubRegistry.inSubRegistry(address(interleave)));
    }

    function testOwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            assetCreditRatings
        );
        vm.stopPrank();

        assertTrue(floorERC1155SubRegistry.inSubRegistry(address(interleave)));
    }

    function testOwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(floorERC1155SubRegistry.inSubRegistry(address(interleave)));
    }

    function testIsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(
            floorERC1155SubRegistry.isWhiteListed(address(interleave), 1)
        );
    }

    function testIsWhitelistedNegativeWrongAddress(address randomAsset) public {
        assertTrue(!floorERC1155SubRegistry.isWhiteListed(randomAsset, 1));
    }

    function testIsWhitelistedNegativeIdOutsideRange(uint256 id) public {
        vm.assume(id != 1);
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        assertTrue(
            !floorERC1155SubRegistry.isWhiteListed(address(interleave), id)
        );
    }

    function testReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountInterleave)
        public
    {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave *
            rateInterleaveToEth *
            rateEthToUsd *
            Constants.WAD) /
            10 **
                (Constants.oracleInterleaveToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(interleave),
                assetId: 1,
                assetAmount: amountInterleave,
                baseCurrency: uint8(Constants.UsdBaseCurrency)
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = floorERC1155SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testreturnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(
        uint128 amountInterleave
    ) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (amountInterleave *
            rateInterleaveToEth *
            Constants.WAD) / 10**(Constants.oracleInterleaveToEthDecimals);

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(interleave),
                assetId: 1,
                assetAmount: amountInterleave,
                baseCurrency: uint8(Constants.EthBaseCurrency)
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = floorERC1155SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountInterleave)
        public
    {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountInterleave *
            rateInterleaveToEth *
            rateEthToUsd *
            Constants.WAD) /
            10 **
                (Constants.oracleInterleaveToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(interleave),
                assetId: 1,
                assetAmount: amountInterleave,
                baseCurrency: uint8(Constants.SafemoonBaseCurrency)
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = floorERC1155SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueSucces(
        uint256 amountInterleave,
        uint256 rateInterleaveToEthNew
    ) public {
        vm.assume(rateInterleaveToEthNew <= uint256(type(int256).max));
        vm.assume(rateInterleaveToEthNew <= type(uint256).max / Constants.WAD);

        if (rateInterleaveToEthNew == 0) {
            vm.assume(
                uint256(amountInterleave) <= type(uint256).max / Constants.WAD
            );
        } else {
            vm.assume(
                uint256(amountInterleave) <=
                    type(uint256).max /
                        Constants.WAD *
                        10**Constants.oracleInterleaveToEthDecimals /
                        uint256(rateInterleaveToEthNew)
            );
        }

        vm.startPrank(oracleOwner);
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEthNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = ((rateInterleaveToEthNew *
            Constants.WAD) / 10**Constants.oracleInterleaveToEthDecimals) *
            amountInterleave;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(interleave),
                assetId: 1,
                assetAmount: amountInterleave,
                baseCurrency: uint8(Constants.EthBaseCurrency)
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = floorERC1155SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueOverflow(
        uint256 amountInterleave,
        uint256 rateInterleaveToEthNew
    ) public {
        vm.assume(rateInterleaveToEthNew <= uint256(type(int256).max));
        vm.assume(rateInterleaveToEthNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateInterleaveToEthNew > 0);

        vm.assume(
            amountInterleave >
                type(uint256).max /
                    Constants.WAD *
                    10**Constants.oracleInterleaveToEthDecimals /
                    uint256(rateInterleaveToEthNew)
        );

        vm.startPrank(oracleOwner);
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEthNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            emptyList
        );
        vm.stopPrank();

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(interleave),
                assetId: 1,
                assetAmount: amountInterleave,
                baseCurrency: uint8(Constants.EthBaseCurrency)
            });
        //Arithmetic overflow.
        vm.expectRevert(stdError.arithmeticError);
        floorERC1155SubRegistry.getValue(getValueInput);
    }
}
