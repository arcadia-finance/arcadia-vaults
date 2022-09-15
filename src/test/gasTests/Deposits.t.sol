/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../../lib/forge-std/src/Test.sol";

import "../../Factory.sol";
import "../../Proxy.sol";
import "../../Vault.sol";
import {ERC20Mock} from "../../mockups/ERC20SolmateMock.sol";
import "../../mockups/ERC721SolmateMock.sol";
import "../../mockups/ERC1155SolmateMock.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";

import "../../utils/Constants.sol";
import "../../ArcadiaOracle.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";

import {LendingPool, ERC20} from "../../../lib/arcadia-lending/src/LendingPool.sol";
import {DebtToken} from "../../../lib/arcadia-lending/src/DebtToken.sol";
import {Tranche} from "../../../lib/arcadia-lending/src/Tranche.sol";


contract gasDeposits is Test {
    using stdStorage for StdStorage;

    Factory private factory;
    Vault private vault;
    Vault private proxy;
    address private proxyAddr;
    ERC20Mock private dai;
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
    ERC1155Mock private genericStoreFront;
    OracleHub private oracleHub;
    ArcadiaOracle private oracleDaiToUsd;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;
    ArcadiaOracle private oracleWbaycToEth;
    ArcadiaOracle private oracleWmaycToUsd;
    ArcadiaOracle private oracleInterleaveToEth;
    ArcadiaOracle private oracleGenericStoreFrontToEth;
    MainRegistry private mainRegistry;
    StandardERC20Registry private standardERC20Registry;
    FloorERC721SubRegistry private floorERC721SubRegistry;
    FloorERC1155SubRegistry private floorERC1155SubRegistry;
    Liquidator private liquidator;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);
    address private unprivilegedAddress = address(4);
    address private vaultOwner = address(6);
    address private liquidityProvider = address(9);

    uint256 rateDaiToUsd = 1 * 10**Constants.oracleDaiToUsdDecimals;
    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);
    uint256 rateGenericStoreFrontToEth = 1 * 10**(8);

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);
    address[] public oracleGenericStoreFrontToEthEthToUsd = new address[](2);

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);

        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        eth.mint(tokenCreatorAddress, 200000 * 10**Constants.ethDecimals);

        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        snx.mint(tokenCreatorAddress, 200000 * 10**Constants.snxDecimals);

        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );
        link.mint(tokenCreatorAddress, 200000 * 10**Constants.linkDecimals);

        safemoon = new ERC20Mock(
            "Safemoon Mock",
            "mSFMN",
            uint8(Constants.safemoonDecimals)
        );
        safemoon.mint(
            tokenCreatorAddress,
            200000 * 10**Constants.safemoonDecimals
        );

        bayc = new ERC721Mock("BAYC Mock", "mBAYC");
        bayc.mint(tokenCreatorAddress, 0);
        bayc.mint(tokenCreatorAddress, 1);
        bayc.mint(tokenCreatorAddress, 2);
        bayc.mint(tokenCreatorAddress, 3);
        bayc.mint(tokenCreatorAddress, 4);
        bayc.mint(tokenCreatorAddress, 5);
        bayc.mint(tokenCreatorAddress, 6);
        bayc.mint(tokenCreatorAddress, 7);
        bayc.mint(tokenCreatorAddress, 8);
        bayc.mint(tokenCreatorAddress, 9);
        bayc.mint(tokenCreatorAddress, 10);
        bayc.mint(tokenCreatorAddress, 11);
        bayc.mint(tokenCreatorAddress, 12);

        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        mayc.mint(tokenCreatorAddress, 0);
        mayc.mint(tokenCreatorAddress, 1);
        mayc.mint(tokenCreatorAddress, 2);
        mayc.mint(tokenCreatorAddress, 3);
        mayc.mint(tokenCreatorAddress, 4);
        mayc.mint(tokenCreatorAddress, 5);
        mayc.mint(tokenCreatorAddress, 6);
        mayc.mint(tokenCreatorAddress, 7);
        mayc.mint(tokenCreatorAddress, 8);
        mayc.mint(tokenCreatorAddress, 9);

        dickButs = new ERC721Mock("DickButs Mock", "mDICK");
        dickButs.mint(tokenCreatorAddress, 0);
        dickButs.mint(tokenCreatorAddress, 1);
        dickButs.mint(tokenCreatorAddress, 2);

        wbayc = new ERC20Mock(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals)
        );
        wbayc.mint(tokenCreatorAddress, 100000 * 10**Constants.wbaycDecimals);

        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
        interleave.mint(tokenCreatorAddress, 1, 100000);
        interleave.mint(tokenCreatorAddress, 2, 100000);
        interleave.mint(tokenCreatorAddress, 3, 100000);
        interleave.mint(tokenCreatorAddress, 4, 100000);
        interleave.mint(tokenCreatorAddress, 5, 100000);

        genericStoreFront = new ERC1155Mock("Generic Storefront Mock", "mGSM");
        genericStoreFront.mint(tokenCreatorAddress, 1, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 2, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 3, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 4, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 5, 100000);

        vm.stopPrank();

        vm.prank(creatorAddress);
        oracleHub = new OracleHub();

        oracleDaiToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleDaiToUsdDecimals),
            "DAI / USD",
            rateDaiToUsd
        );
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
        oracleGenericStoreFrontToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(10),
            "GenericStoreFront / ETH",
            rateGenericStoreFrontToEth
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
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10**10),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "GenericStoreFront",
                baseAsset: "ETH",
                oracleAddress: address(oracleGenericStoreFrontToEth),
                quoteAssetAddress: address(genericStoreFront),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        eth.transfer(vaultOwner, 100000 * 10**Constants.ethDecimals);
        link.transfer(vaultOwner, 100000 * 10**Constants.linkDecimals);
        snx.transfer(vaultOwner, 100000 * 10**Constants.snxDecimals);
        safemoon.transfer(vaultOwner, 100000 * 10**Constants.safemoonDecimals);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 4);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 5);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 6);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 7);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 8);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 9);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 10);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 11);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 12);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 4);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 5);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 6);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 7);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 8);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 9);
        dickButs.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            2,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            2,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        eth.transfer(unprivilegedAddress, 1000 * 10**Constants.ethDecimals);
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

        oracleGenericStoreFrontToEthEthToUsd[0] = address(
            oracleGenericStoreFrontToEth
        );
        oracleGenericStoreFrontToEthEthToUsd[1] = address(oracleEthToUsd);

        vm.prank(creatorAddress);
        factory = new Factory();

        vm.startPrank(tokenCreatorAddress);
        dai.mint(liquidityProvider, type(uint128).max);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.updateInterestRate(5 * 10**16); //5% with 18 decimals precision

        debt = new DebtToken(address(pool));
        pool.setDebtToken(address(debt));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);


        vm.prank(address(tranche));
        pool.deposit(type(uint128).max, liquidityProvider);
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
        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(
                    10**Constants.oracleDaiToUsdDecimals
                ),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnit: uint64(10**Constants.daiDecimals)
            }),
            emptyList
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

        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        mainRegistry.addSubRegistry(address(floorERC1155SubRegistry));

        uint256[] memory assetCreditRatings = new uint256[](3);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        assetCreditRatings[2] = 0;

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatings
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            assetCreditRatings
        );

        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWmaycToUsdArr,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(mayc)
            }),
            assetCreditRatings
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            assetCreditRatings
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleGenericStoreFrontToEthEthToUsd,
                id: 1,
                assetAddress: address(genericStoreFront)
            }),
            assetCreditRatings
        );

        liquidator = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = new Vault();
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            Constants.upgradeProof1To2
        );
        factory.confirmNewVaultInfo();
        factory.setLiquidator(address(liquidator));
        pool.setLiquidator(address(liquidator));
        liquidator.setFactory(address(factory));
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)",
                        block.timestamp,
                        block.number,
                        blockhash(block.number)
                    )
                )
            ),
            0
        );
        proxy = Vault(proxyAddr);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        oracleWmaycToUsd.transmit(int256(rateWmaycToUsd));
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEth));
        vm.stopPrank();

        vm.roll(1); //increase block for random salt

        vm.prank(tokenCreatorAddress);
        eth.mint(vaultOwner, 1e18);

        vm.startPrank(vaultOwner);
        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(proxy), type(uint256).max);

        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        genericStoreFront.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        dai.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
    }

    function test1_1_ERC20() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1e18;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test2_2_ERC20s() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 10**Constants.ethDecimals;
        assetAmounts[1] = 10**Constants.linkDecimals;

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 0;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test3_3_ERC20s() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(snx);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 10**Constants.ethDecimals;
        assetAmounts[1] = 10**Constants.linkDecimals;
        assetAmounts[2] = 10**Constants.snxDecimals;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 0;
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test4_1_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        assetIds = new uint256[](1);
        assetIds[0] = 1;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test5_2_same_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(bayc);
        assetAddresses[1] = address(bayc);

        assetIds = new uint256[](2);
        assetIds[0] = 2;
        assetIds[1] = 3;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 1;
        assetTypes[1] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test6_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(bayc);
        assetAddresses[1] = address(mayc);

        assetIds = new uint256[](2);
        assetIds[0] = 4;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 1;
        assetTypes[1] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test7_1_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        assetIds = new uint256[](1);
        assetIds[0] = 1;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        assetTypes = new uint256[](1);
        assetTypes[0] = 2;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test8_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(interleave);
        assetAddresses[1] = address(genericStoreFront);

        assetIds = new uint256[](2);
        assetIds[0] = 1;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 2;
        assetTypes[1] = 2;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test9_1_ERC20_1_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);

        assetIds = new uint256[](2);
        assetIds[0] = 1;
        assetIds[1] = 5;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test10_1_ERC20_2_same_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(bayc);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 6;
        assetIds[2] = 7;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test11_1_ERC20_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 8;
        assetIds[2] = 2;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test12_2_ERC20_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](4);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);
        assetAddresses[3] = address(snx);

        assetIds = new uint256[](4);
        assetIds[0] = 0;
        assetIds[1] = 9;
        assetIds[2] = 3;
        assetIds[3] = 0;

        assetAmounts = new uint256[](4);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 100;

        assetTypes = new uint256[](4);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 0;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test13_2_ERC20_2_same_ERC721_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](6);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(bayc);
        assetAddresses[3] = address(interleave);
        assetAddresses[4] = address(genericStoreFront);
        assetAddresses[5] = address(snx);

        assetIds = new uint256[](6);
        assetIds[0] = 0;
        assetIds[1] = 10;
        assetIds[2] = 11;
        assetIds[3] = 1;
        assetIds[4] = 1;
        assetIds[5] = 1;

        assetAmounts = new uint256[](6);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 10;
        assetAmounts[4] = 10;
        assetAmounts[5] = 100;

        assetTypes = new uint256[](6);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 2;
        assetTypes[4] = 2;
        assetTypes[5] = 0;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function test14_2_ERC20_2_diff_ERC721_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](6);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);
        assetAddresses[3] = address(interleave);
        assetAddresses[4] = address(genericStoreFront);
        assetAddresses[5] = address(snx);

        assetIds = new uint256[](6);
        assetIds[0] = 0;
        assetIds[1] = 12;
        assetIds[2] = 4;
        assetIds[3] = 1;
        assetIds[4] = 1;
        assetIds[5] = 1;

        assetAmounts = new uint256[](6);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 10;
        assetAmounts[4] = 10;
        assetAmounts[5] = 100;

        assetTypes = new uint256[](6);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 2;
        assetTypes[4] = 2;
        assetTypes[5] = 0;

        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }
}
