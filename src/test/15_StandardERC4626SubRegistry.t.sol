/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import {ERC4626Mock} from "../mockups/ERC4626Mock.sol";
import {ERC20Mock} from "../mockups/ERC20SolmateMock.sol";
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
    ERC4626Mock private ybEth;

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
        ybEth = new ERC4626Mock(eth, "ybETH Mock", "mybETH", uint8(Constants.ethDecimals));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                liquidityPool: 0x0000000000000000000000000000000000000000,
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
                liquidityPool: 0x0000000000000000000000000000000000000000,
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
                liquidityPool: 0x0000000000000000000000000000000000000000,
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

    function testRevert_OwnerAddsAssetWithWrongNumberOfDecimals() public {
        
        ybEth = new ERC4626Mock(eth, "ybETH Mock", "mybETH", uint8(Constants.ethDecimals) - 1);
           
        vm.startPrank(creatorAddress);
        vm.expectRevert("SR: Decimals of asset and underlying don't match");
        standardERC4626SubRegistry.setAssetInformation(
            address(ybEth),
            emptyList
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

    function testReturnValueZeroTotalSupply(uint256 rateEthToUsd_, uint256 totalAssets) public {
        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = 0;

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
                  address(ybEth),
            emptyList
        );
        vm.stopPrank();

        //Cheat balance of
        uint256 slot2 = stdstore
            .target(address(eth))
            .sig(ybEth.balanceOf.selector)
            .with_key(address(ybEth))
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: 0,
                baseCurrency: 0
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = standardERC4626SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueSucces(uint256 rateEthToUsd_, uint256 shares, uint256 totalSupply, uint256 totalAssets) public {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);
        
        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);
        if (totalAssets > 0) {
            vm.assume(shares <= type(uint256).max / totalAssets);
        }
        if (rateEthToUsd_ == 0) {
            vm.assume(shares * totalAssets / totalSupply <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                shares * totalAssets / totalSupply <=
                    type(uint256).max / 
                        Constants.WAD *
                        10**Constants.oracleEthToUsdDecimals /
                        uint256(rateEthToUsd_)
            );
        }

        uint256 expectedValueInUsd = (shares * totalAssets / totalSupply) * 
            (Constants.WAD * rateEthToUsd_ / 10**Constants.oracleEthToUsdDecimals) /
            10**Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
                  address(ybEth),
            emptyList
        );
        vm.stopPrank();

        //Cheat totalSupply
        uint256 slot = stdstore
            .target(address(ybEth))
            .sig(ybEth.totalSupply.selector)
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedTotalSupply = bytes32(abi.encode(totalSupply));
        vm.store(address(ybEth), loc, mockedTotalSupply);

        //Cheat balance of
        uint256 slot2 = stdstore
            .target(address(eth))
            .sig(ybEth.balanceOf.selector)
            .with_key(address(ybEth))
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: shares,
                baseCurrency: 0
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInBaseCurrency
        ) = standardERC4626SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueOverflow(uint256 rateEthToUsd_, uint256 shares, uint256 totalSupply, uint256 totalAssets)
        public
    {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);
        vm.assume(totalAssets > 0);
        vm.assume(rateEthToUsd_ > 0);
        
        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);
        vm.assume(shares <= type(uint256).max / totalAssets);

        vm.assume(
            shares * totalAssets / totalSupply >
                type(uint256).max / 
                    Constants.WAD *
                    10**Constants.oracleEthToUsdDecimals /
                    uint256(rateEthToUsd_)
        );

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626SubRegistry.setAssetInformation(
                  address(ybEth),
            emptyList
        );
        vm.stopPrank();

        //Cheat totalSupply
        uint256 slot = stdstore
            .target(address(ybEth))
            .sig(ybEth.totalSupply.selector)
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedTotalSupply = bytes32(abi.encode(totalSupply));
        vm.store(address(ybEth), loc, mockedTotalSupply);

        //Cheat balance of
        uint256 slot2 = stdstore
            .target(address(eth))
            .sig(ybEth.balanceOf.selector)
            .with_key(address(ybEth))
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(ybEth),
                assetId: 0,
                assetAmount: shares,
                baseCurrency: 0
            });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        standardERC4626SubRegistry.getValue(getValueInput);
    }
}