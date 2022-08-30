/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC4626SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/StandardERC4626SubRegistry.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract standardERC4626SubRegistryTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    MockERC4626 private ybEth;

    ArcadiaOracle private oracleEthToUsd;

    StandardERC20Registry private standardERC20SubRegistry;
    StandardERC4626SubRegistry private standardERC4626SubRegistry;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 1850 * 10**Constants.oracleEthToUsdDecimals;

    address[] public oracleEthToUsdArr = new address[](1);

    uint256[] emptyList = new uint256[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
    new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        ybEth = new MockERC4626(eth, "ybETH Mock", "mybETH");
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
        vm.stopPrank();

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
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

        standardERC20SubRegistry = new StandardERC20Registry(
            address(mainRegistry),
            address(oracleHub)
        );

        standardERC4626SubRegistry = new StandardERC4626SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addSubRegistry(address(standardERC20SubRegistry));
        mainRegistry.addSubRegistry(address(standardERC4626SubRegistry));

        standardERC20SubRegistry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        vm.stopPrank();
    }

    function testRevert_NonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            emptyList
        );
        vm.stopPrank();
    }

    function testRevert_OwnerAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testSuccess_OwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            emptyList
        );
        vm.stopPrank();

        assertTrue(standardERC4626SubRegistry.inSubRegistry(address(ybEth)));
    }

    function testSuccess_OwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            assetCreditRatings
        );
        vm.stopPrank();

        assertTrue(standardERC4626SubRegistry.inSubRegistry(address(ybEth)));
    }

    function testSuccess_OwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            emptyList
        );
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            emptyList
        );
        vm.stopPrank();

        assertTrue(standardERC4626SubRegistry.inSubRegistry(address(ybEth)));
    }

    function testSuccess_IsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);

        standardERC4626SubRegistry.setAssetInformation(
        address(ybEth),
        emptyList
        );
        vm.stopPrank();

        assertTrue(standardERC4626SubRegistry.isWhiteListed(address(ybEth), 0));
    }

    function testSuccess_IsWhitelistedNegative(address randomAsset) public {
        assertTrue(!standardERC4626SubRegistry.isWhiteListed(randomAsset, 0));
    }

    function testReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
         address(ybEth),
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
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });

        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = standardERC4626SubRegistry.getValue(getValueInput);

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
        standardERC4626SubRegistry.setAssetInformation(
                  address(ybEth),
            emptyList
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (((Constants.WAD * rateEthToUsdNew) /
            10**Constants.oracleEthToUsdDecimals) * amountEth) /
            10**Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = standardERC4626SubRegistry.getValue(getValueInput);

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
        standardERC4626SubRegistry.setAssetInformation(
               address(ybEth),
            emptyList
        );
        vm.stopPrank();

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: amountEth,
                baseCurrency: 0
            });
        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        standardERC4626SubRegistry.getValue(getValueInput);
    }
}