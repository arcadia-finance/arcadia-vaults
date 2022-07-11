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
import "../../mockups/ERC20SolmateMock.sol";
import "../../mockups/ERC721SolmateMock.sol";
import "../../mockups/ERC1155SolmateMock.sol";
import "../../Stable.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";

import "../../utils/Constants.sol";
import "../../ArcadiaOracle.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";

contract gasVaultAuction_1ERC20 is Test {
    using stdStorage for StdStorage;

    Factory private factory;
    Vault private vault;
    Vault private proxy;
    address private proxyAddr;
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
    InterestRateModule private interestRateModule;
    Stable private stable;
    Liquidator private liquidator;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);
    address private unprivilegedAddress = address(4);
    address private stakeContract = address(5);
    address private vaultOwner = address(6);
    address private liquidatorBot = address(7);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);
    uint256 rateGenericStoreFrontToEth = 1 * 10**(8);

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);
    address[] public oracleGenericStoreFrontToEthEthToUsd = new address[](2);

    address[] public s_assetAddresses;
    uint256[] public s_assetIds;
    uint256[] public s_assetAmounts;
    uint256[] public s_assetTypes;

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);

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
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10**10),
                baseAssetNumeraire: 1,
                quoteAsset: "GenericStoreFront",
                baseAsset: "ETH",
                oracleAddress: address(oracleGenericStoreFrontToEth),
                quoteAssetAddress: address(genericStoreFront),
                baseAssetIsNumeraire: true
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

        vm.startPrank(creatorAddress);
        interestRateModule = new InterestRateModule();
        interestRateModule.setBaseInterestRate(5 * 10**16);
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        stable = new Stable(
            "Arcadia Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
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

        oracleGenericStoreFrontToEthEthToUsd[0] = address(
            oracleGenericStoreFrontToEth
        );
        oracleGenericStoreFrontToEthEthToUsd[1] = address(oracleEthToUsd);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: address(stable),
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );
        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: address(stable),
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
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

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;

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
        stable.transfer(address(0), stable.balanceOf(vaultOwner));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factory.confirmNewVaultInfo();
        factory.setLiquidator(address(liquidator));
        liquidator.setFactory(address(factory));
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        stable.setLiquidator(address(liquidator));
        stable.setFactory(address(factory));
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
            Constants.UsdNumeraire
        );
        proxy = Vault(proxyAddr);

        vm.prank(address(proxy));
        stable.mint(
            tokenCreatorAddress,
            10000000 * 10**Constants.stableDecimals
        );
        vm.prank(tokenCreatorAddress);
        stable.transfer(vaultOwner, 10000000 * 10**Constants.stableDecimals);

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
        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        genericStoreFront.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        stable.approve(address(proxy), type(uint256).max);
        stable.approve(address(liquidator), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(vaultOwner);

        s_assetAddresses = new address[](1);
        s_assetAddresses[0] = address(eth);

        s_assetIds = new uint256[](1);
        s_assetIds[0] = 0;

        s_assetAmounts = new uint256[](1);
        s_assetAmounts[0] = 10**Constants.ethDecimals;

        s_assetTypes = new uint256[](1);
        s_assetTypes[0] = 0;

        proxy.deposit(
            s_assetAddresses,
            s_assetIds,
            s_assetAmounts,
            s_assetTypes
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        uint256 valueEth = (((10**18 * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * s_assetAmounts[0]) /
            10**Constants.ethDecimals;
        proxy.takeCredit(uint128((valueEth * 100) / 150));

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd) / 2);

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));
    }

    function testAuctionPriceStart() public {
        vm.roll(1); //compile warning to make it a view
        liquidator.getPriceOfVault(address(proxy), 0);
    }

    function testAuctionPriceBl100() public {
        vm.roll(100);
        liquidator.getPriceOfVault(address(proxy), 0);
    }

    function testAuctionPriceBl500() public {
        vm.roll(500);
        liquidator.getPriceOfVault(address(proxy), 0);
    }

    function testAuctionPriceBl1000() public {
        vm.roll(1000);
        liquidator.getPriceOfVault(address(proxy), 0);
    }

    function testAuctionPriceBl1500() public {
        vm.roll(1500);
        liquidator.getPriceOfVault(address(proxy), 0);
    }

    function testAuctionPriceBl2000() public {
        vm.roll(2000);
        liquidator.getPriceOfVault(address(proxy), 0);
    }
}
