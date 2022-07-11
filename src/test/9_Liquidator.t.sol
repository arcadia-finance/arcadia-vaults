/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../Factory.sol";
import "../Proxy.sol";
import "../Vault.sol";
import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../Stable.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract LiquidatorTest is Test {
    using stdStorage for StdStorage;

    Factory private factory;
    Vault internal vault;
    Vault internal proxy;
    address internal proxyAddr;
    ERC20Mock internal eth;
    ERC20Mock internal snx;
    ERC20Mock internal link;
    ERC20Mock internal safemoon;
    ERC721Mock internal bayc;
    ERC721Mock internal mayc;
    ERC721Mock internal dickButs;
    ERC20Mock internal wbayc;
    ERC20Mock internal wmayc;
    ERC1155Mock internal interleave;
    OracleHub internal oracleHub;
    ArcadiaOracle internal oracleEthToUsd;
    ArcadiaOracle internal oracleLinkToUsd;
    ArcadiaOracle internal oracleSnxToEth;
    ArcadiaOracle internal oracleWbaycToEth;
    ArcadiaOracle internal oracleWmaycToUsd;
    ArcadiaOracle internal oracleInterleaveToEth;
    MainRegistry internal mainRegistry;
    StandardERC20Registry internal standardERC20Registry;
    FloorERC721SubRegistry internal floorERC721SubRegistry;
    FloorERC1155SubRegistry internal floorERC1155SubRegistry;
    InterestRateModule internal interestRateModule;
    Stable internal stable;
    Liquidator internal liquidator;

    address internal creatorAddress = address(1);
    address internal tokenCreatorAddress = address(2);
    address internal oracleOwner = address(3);
    address internal unprivilegedAddress = address(4);
    address internal stakeContract = address(5);
    address internal vaultOwner = address(6);
    address internal liquidatorBot = address(7);
    address internal auctionBuyer = address(8);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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

        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        mayc.mint(tokenCreatorAddress, 0);

        dickButs = new ERC721Mock("DickButs Mock", "mDICK");
        dickButs.mint(tokenCreatorAddress, 0);

        wbayc = new ERC20Mock(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals)
        );
        wbayc.mint(tokenCreatorAddress, 100000 * 10**Constants.wbaycDecimals);

        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
        interleave.mint(tokenCreatorAddress, 1, 100000);

        vm.stopPrank();

        vm.prank(creatorAddress);
        oracleHub = new OracleHub();

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
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "WBAYC / ETH"
        );
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "WMAYC / USD"
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / ETH"
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
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        dickButs.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
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
    }

    //this is a before each
    function setUp() public virtual {
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

        liquidator = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = new Vault();
        stable.transfer(address(0), stable.balanceOf(vaultOwner));
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        stable.setLiquidator(address(liquidator));
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

        uint256 slot = stdstore
            .target(address(factory))
            .sig(factory.isVault.selector)
            .with_key(address(vault))
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factory), loc, mockedCurrentTokenId);

        vm.prank(address(proxy));
        stable.mint(tokenCreatorAddress, 100000 * 10**Constants.stableDecimals);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        oracleWmaycToUsd.transmit(int256(rateWmaycToUsd));
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEth));
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        stable.approve(address(proxy), type(uint256).max);
        stable.approve(address(liquidator), type(uint256).max);
        vm.stopPrank();

        vm.prank(auctionBuyer);
        stable.approve(address(liquidator), type(uint256).max);
    }

    function testTransferOwnership(address to) public {
        vm.assume(to != address(0));
        Liquidator liquidator_m = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );

        assertEq(address(this), liquidator_m.owner());

        liquidator_m.transferOwnership(to);
        assertEq(to, liquidator_m.owner());
    }

    function testTransferOwnershipByNonOwner(address from) public virtual {
        vm.assume(from != address(this) && from != address(factory));

        Liquidator liquidator_m = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        address to = address(12345);

        assertEq(address(this), liquidator_m.owner());

        vm.startPrank(from);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator_m.transferOwnership(to);
        assertEq(address(this), liquidator_m.owner());
    }

    function testNotAllowAuctionHealthyVault(
        uint128 amountEth,
        uint128 amountCredit
    ) public virtual {
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        vm.assume(
            ((valueOfOneEth * amountEth) / 10**Constants.ethDecimals / 150) *
                100 >=
                amountCredit
        );
        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.startPrank(liquidatorBot);
        vm.expectRevert("This vault is healthy");
        factory.liquidate(address(proxy));
        vm.stopPrank();

        assertEq(proxy.life(), 0);
    }

    function testStartAuction(uint128 amountEth, uint256 newPrice)
        public
        virtual
    {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        depositERC20InVault(eth, amountEth, vaultOwner);
        assertEq(proxy.life(), 0);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.startPrank(liquidatorBot);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(vaultOwner, address(liquidator));
        factory.liquidate(address(proxy));
        vm.stopPrank();

        assertEq(proxy.life(), 1);
    }

    function testShowVaultAuctionPrice(uint128 amountEth, uint256 newPrice)
        public
        virtual
    {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        (, , uint8 liqThres, , , , , ) = liquidator.auctionInfo(
            address(proxy),
            0
        );

        (uint256 vaultPrice, , bool forSale) = liquidator.getPriceOfVault(
            address(proxy),
            0
        );

        uint256 expectedPrice = (amountCredit * liqThres) / 100;
        assertTrue(forSale);
        assertEq(vaultPrice, expectedPrice);
    }

    function testAuctionPriceDecrease(
        uint128 amountEth,
        uint256 newPrice,
        uint64 blocksToRoll
    ) public virtual {
        vm.assume(
            blocksToRoll <
                liquidator.hourlyBlocks() * liquidator.breakevenTime()
        );
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        (uint128 openDebt, , uint8 liqThres, , , , , ) = liquidator.auctionInfo(
            address(proxy),
            0
        );
        (uint256 vaultPriceBefore, , bool forSaleBefore) = liquidator
            .getPriceOfVault(address(proxy), 0);

        vm.roll(block.number + blocksToRoll);
        (uint256 vaultPriceAfter, , bool forSaleAfter) = liquidator
            .getPriceOfVault(address(proxy), 0);

        uint256 expectedPrice = ((openDebt * liqThres) / 100) -
            ((blocksToRoll * ((openDebt * (liqThres - 100)) / 100)) /
                (liquidator.hourlyBlocks() * liquidator.breakevenTime()));

        emit log_named_uint("expectedPrice", expectedPrice);

        assertTrue(forSaleBefore);
        assertTrue(forSaleAfter);
        assertGe(vaultPriceBefore, vaultPriceAfter);
        assertEq(vaultPriceAfter, expectedPrice);
    }

    function testBuyVault(
        uint128 amountEth,
        uint256 newPrice,
        uint64 blocksToRoll
    ) public virtual {
        vm.assume(
            blocksToRoll >
                liquidator.hourlyBlocks() * liquidator.breakevenTime()
        );
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        (uint256 priceOfVault, , ) = liquidator.getPriceOfVault(
            address(proxy),
            0
        );
        vm.prank(address(proxy));
        stable.mint(auctionBuyer, priceOfVault);

        vm.prank(auctionBuyer);
        liquidator.buyVault(address(proxy), 0);

        assertEq(proxy.owner(), auctionBuyer); //todo: check erc721 owner
    }

    function testWithrawAssetsFromPurchasedVault(
        uint128 amountEth,
        uint256 newPrice,
        uint64 blocksToRoll
    ) public virtual {
        vm.assume(
            blocksToRoll >
                liquidator.hourlyBlocks() * liquidator.breakevenTime()
        );
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        (uint256 priceOfVault, , ) = liquidator.getPriceOfVault(
            address(proxy),
            0
        );
        vm.prank(address(proxy));
        stable.mint(auctionBuyer, priceOfVault);

        vm.prank(auctionBuyer);
        liquidator.buyVault(address(proxy), 0);

        assertEq(proxy.owner(), auctionBuyer);

        vm.startPrank(auctionBuyer);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(proxy), auctionBuyer, assetAmounts[0]);
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    struct Rewards {
        uint256 expectedKeeperReward;
        uint256 expectedProtocolReward;
        uint256 originalOwnerRecovery;
    }

    struct Balances {
        uint256 keeper;
        uint256 protocol;
        uint256 originalOwner;
    }

    function testClaimSingle(uint128 amountEth) public virtual {
        vm.assume(amountEth > 0);
        {
            uint256 valueOfOneEth = rateEthToUsd *
                10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
            vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        }

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        uint256 remainingCred = uint128(proxy.getRemainingCredit());
        proxy.takeCredit(uint128(remainingCred));
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd / 2));
        vm.stopPrank();

        // address protocolTreasury = address(1000);
        // address reserveFund = address(1111);
        // address liquidatorKeeper = address(1110);
        // address vaultBuyer = address(2000);

        setAddresses();

        vm.prank(address(1110));
        factory.liquidate(address(proxy));

        giveStable(address(2000), remainingCred * 2);
        giveStable(address(1111), remainingCred * 2);
        (uint256 price, , ) = liquidator.getPriceOfVault(address(proxy), 0);
        vm.startPrank(address(2000));
        stable.approve(address(liquidator), type(uint256).max);
        liquidator.buyVault(address(proxy), 0);
        vm.stopPrank();

        address[] memory vaultAddresses = new address[](1);
        uint256[] memory lives = new uint256[](1);
        vaultAddresses[0] = address(proxy);
        lives[0] = 0;

        Liquidator.auctionInformation memory auction;
        auction.stablePaid = uint128(price);
        auction.openDebt = uint128(remainingCred);
        auction.originalOwner = vaultOwner;
        auction.liquidationKeeper = address(1110);
        auction.numeraire = 0;

        liquidator.claimable(auction, address(proxy), 0);

        Balances memory pre = getBalances(stable, vaultOwner);

        liquidator.claimProceeds(address(1110), vaultAddresses, lives);
        liquidator.claimProceeds(address(1000), vaultAddresses, lives);
        liquidator.claimProceeds(vaultOwner, vaultAddresses, lives);

        Rewards memory rewards = getRewards(price, remainingCred);

        Balances memory post = getBalances(stable, vaultOwner);

        assertEq(pre.keeper + rewards.expectedKeeperReward, post.keeper);
        assertEq(pre.protocol + rewards.expectedProtocolReward, post.protocol);
        assertEq(
            pre.originalOwner + rewards.originalOwnerRecovery,
            post.originalOwner
        );
    }

    function testClaimMultiple(uint128[] calldata amountsEth) public virtual {
        vm.assume(amountsEth.length < 10);
        setAddresses();

        address[] memory vaultAddresses = new address[](amountsEth.length);
        uint256[] memory lives = new uint256[](amountsEth.length);

        uint128 amountEth;
        uint256 remainingCred;
        uint256 valueOfOneEth;
        uint256 price;
        Rewards[] memory rewards = new Rewards[](amountsEth.length);
        Rewards memory rewardsSum;
        giveStable(address(2000), type(uint256).max);
        giveStable(address(1111), type(uint256).max);
        emit log_named_uint(
            "bal of buyer pre",
            stable.balanceOf(address(2000))
        );

        for (uint256 i; i < amountsEth.length; ++i) {
            amountEth = amountsEth[i];
            vm.assume(amountEth > 0);
            {
                valueOfOneEth =
                    rateEthToUsd *
                    10 **
                        (Constants.usdDecimals -
                            Constants.oracleEthToUsdDecimals);
                vm.assume(amountEth < type(uint128).max / valueOfOneEth);
            }

            emit log_named_address("vaultOwner", proxy.owner());
            emit log_named_address("vaultBuyer", address(2000));
            emit log_named_uint("loopindex", i);
            depositERC20InVault(eth, amountEth, vaultOwner);

            vm.startPrank(vaultOwner);
            remainingCred = uint128(proxy.getRemainingCredit());
            proxy.takeCredit(uint128(remainingCred));
            vm.stopPrank();

            vm.startPrank(oracleOwner);
            oracleEthToUsd.transmit(int256(rateEthToUsd / 2));
            vm.stopPrank();

            // address protocolTreasury = address(1000);
            // address reserveFund = address(1111);
            // address liquidatorKeeper = address(1110);
            // address vaultBuyer = address(2000);

            vm.prank(address(1110));
            factory.liquidate(address(proxy));

            (price, , ) = liquidator.getPriceOfVault(address(proxy), i);

            vm.startPrank(address(2000));
            stable.approve(address(liquidator), type(uint256).max);
            emit log_named_uint(
                "bal of buyer",
                stable.balanceOf(address(2000))
            );
            emit log_named_uint("priceToPay", price);
            liquidator.buyVault(address(proxy), i);
            vm.stopPrank();

            rewards[i] = getRewards(price, remainingCred);
            rewardsSum.expectedKeeperReward += rewards[i].expectedKeeperReward;
            rewardsSum.expectedProtocolReward += rewards[i]
                .expectedProtocolReward;
            rewardsSum.originalOwnerRecovery += rewards[i]
                .originalOwnerRecovery;

            vm.prank(oracleOwner);
            oracleEthToUsd.transmit(int256(rateEthToUsd));

            vaultAddresses[i] = address(proxy);
            lives[i] = i;
            vm.startPrank(address(2000));
            factory.transferFrom(
                address(2000),
                vaultOwner,
                factory.vaultIndex(address(proxy))
            );
            vm.stopPrank();
        }

        Balances memory pre = getBalances(stable, vaultOwner);

        liquidator.claimProceeds(address(1110), vaultAddresses, lives);
        liquidator.claimProceeds(address(1000), vaultAddresses, lives);
        liquidator.claimProceeds(vaultOwner, vaultAddresses, lives);

        Balances memory post = getBalances(stable, vaultOwner);

        assertEq(pre.keeper + rewardsSum.expectedKeeperReward, post.keeper);
        assertEq(
            pre.protocol + rewardsSum.expectedProtocolReward,
            post.protocol
        );
        assertEq(
            pre.originalOwner + rewardsSum.originalOwnerRecovery,
            post.originalOwner
        );
    }

    function testClaimSingleMultipleVaults(uint128 amountEth) public virtual {
        vm.assume(amountEth > 0);
        {
            uint256 valueOfOneEth = rateEthToUsd *
                10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
            vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        }

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(tokenCreatorAddress);
        eth.mint(vaultOwner, amountEth * 2);

        vm.startPrank(vaultOwner);
        address proxy2 = factory.createVault(45855465656845214, 0);
        eth.approve(proxy2, type(uint256).max);
        Vault(proxy2).deposit(
            assetAddresses,
            assetIds,
            assetAmounts,
            assetTypes
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        uint256 remainingCred = uint128(proxy.getRemainingCredit());
        proxy.takeCredit(uint128(remainingCred));
        Vault(proxy2).takeCredit(uint128(remainingCred));
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd / 2));
        vm.stopPrank();

        // address protocolTreasury = address(1000);
        // address reserveFund = address(1111);
        // address liquidatorKeeper = address(1110);
        // address vaultBuyer = address(2000);

        setAddresses();

        vm.startPrank(address(1110));
        factory.liquidate(address(proxy));
        factory.liquidate(proxy2);
        vm.stopPrank();

        giveStable(address(2000), remainingCred * 10);
        giveStable(address(1111), remainingCred * 10);
        (uint256 price, , ) = liquidator.getPriceOfVault(address(proxy), 0);
        vm.startPrank(address(2000));
        stable.approve(address(liquidator), type(uint256).max);
        liquidator.buyVault(address(proxy), 0);
        liquidator.buyVault(address(proxy2), 0);
        vm.stopPrank();

        address[] memory vaultAddresses = new address[](2);
        uint256[] memory lives = new uint256[](2);
        vaultAddresses[0] = address(proxy);
        vaultAddresses[1] = proxy2;
        lives[0] = 0;
        lives[1] = 0;

        Balances memory pre = getBalances(stable, vaultOwner);

        Liquidator.auctionInformation memory auction1;
        Liquidator.auctionInformation memory auction2;

        auction1.openDebt = uint128(remainingCred);
        auction2.openDebt = uint128(remainingCred);
        auction1.liquidationKeeper = address(1110);
        auction2.liquidationKeeper = address(1110);
        auction1.stablePaid = uint128(price);
        auction2.stablePaid = uint128(price);
        auction1.originalOwner = vaultOwner;
        auction2.originalOwner = vaultOwner;

        liquidator.claimable(auction1, address(proxy), 0);
        liquidator.claimable(auction2, address(proxy2), 0);

        liquidator.claimProceeds(address(1110), vaultAddresses, lives);
        liquidator.claimProceeds(address(1000), vaultAddresses, lives);
        liquidator.claimProceeds(vaultOwner, vaultAddresses, lives);

        Rewards memory rewards = getRewards(price, remainingCred);

        Balances memory post = getBalances(stable, vaultOwner);

        assertEq(pre.keeper + 2 * rewards.expectedKeeperReward, post.keeper);
        assertEq(
            pre.protocol + 2 * rewards.expectedProtocolReward,
            post.protocol
        );
        assertEq(
            pre.originalOwner + 2 * rewards.originalOwnerRecovery,
            post.originalOwner
        );
    }

    function testClaimSingleHighLife(uint128 amountEth, uint16 newLife)
        public
        virtual
    {
        vm.assume(amountEth > 0);
        {
            uint256 valueOfOneEth = rateEthToUsd *
                10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
            vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        }

        setLife(proxy, newLife);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        uint256 remainingCred = uint128(proxy.getRemainingCredit());
        proxy.takeCredit(uint128(remainingCred));
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd / 2));
        vm.stopPrank();

        // address protocolTreasury = address(1000);
        // address reserveFund = address(1111);
        // address liquidatorKeeper = address(1110);
        // address vaultBuyer = address(2000);

        setAddresses();

        vm.prank(address(1110));
        factory.liquidate(address(proxy));

        giveStable(address(2000), remainingCred * 2);
        giveStable(address(1111), remainingCred * 2);
        (uint256 price, , ) = liquidator.getPriceOfVault(
            address(proxy),
            newLife
        );
        vm.startPrank(address(2000));
        stable.approve(address(liquidator), type(uint256).max);
        liquidator.buyVault(address(proxy), newLife);
        vm.stopPrank();

        address[] memory vaultAddresses = new address[](1);
        uint256[] memory lives = new uint256[](1);
        vaultAddresses[0] = address(proxy);
        lives[0] = newLife;

        Liquidator.auctionInformation memory auction;
        auction.stablePaid = uint128(price);
        auction.openDebt = uint128(remainingCred);
        auction.originalOwner = vaultOwner;
        auction.liquidationKeeper = address(1110);
        auction.numeraire = 0;

        liquidator.claimable(auction, address(proxy), newLife);

        Balances memory pre = getBalances(stable, vaultOwner);

        liquidator.claimProceeds(address(1110), vaultAddresses, lives);
        liquidator.claimProceeds(address(1000), vaultAddresses, lives);
        liquidator.claimProceeds(vaultOwner, vaultAddresses, lives);

        Rewards memory rewards = getRewards(price, remainingCred);

        Balances memory post = getBalances(stable, vaultOwner);

        assertEq(pre.keeper + rewards.expectedKeeperReward, post.keeper);
        assertEq(pre.protocol + rewards.expectedProtocolReward, post.protocol);
        assertEq(
            pre.originalOwner + rewards.originalOwnerRecovery,
            post.originalOwner
        );
    }

    function testClaimSingleWrongLife(
        uint128 amountEth,
        uint16 newLife,
        uint16 lifeToBuy
    ) public virtual {
        vm.assume(newLife != lifeToBuy);
        vm.assume(amountEth > 0);
        {
            uint256 valueOfOneEth = rateEthToUsd *
                10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
            vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        }

        setLife(proxy, newLife);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        uint256 remainingCred = uint128(proxy.getRemainingCredit());
        proxy.takeCredit(uint128(remainingCred));
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd / 2));
        vm.stopPrank();

        // address protocolTreasury = address(1000);
        // address reserveFund = address(1111);
        // address liquidatorKeeper = address(1110);
        // address vaultBuyer = address(2000);

        setAddresses();

        vm.prank(address(1110));
        factory.liquidate(address(proxy));

        giveStable(address(2000), remainingCred * 2);
        giveStable(address(1111), remainingCred * 2);
        //liquidator.getPriceOfVault(address(proxy), newLife);
        liquidator.getPriceOfVault(address(proxy), lifeToBuy);
        vm.startPrank(address(2000));
        stable.approve(address(liquidator), type(uint256).max);
        vm.expectRevert("LQ_BV: Not for sale");
        liquidator.buyVault(address(proxy), lifeToBuy);
        vm.stopPrank();
    }


    function testBreakeven(
        uint128 amountEth,
        uint256 newPrice,
        uint64 blocksToRoll,
        uint8 breakevenTime) public virtual {
        vm.assume(
            blocksToRoll <
                liquidator.hourlyBlocks() * breakevenTime
        );
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd *
            10**(Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(creatorAddress);
        liquidator.setBreakevenTime(breakevenTime);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        (uint128 openDebt, , uint8 liqThres, , , , , ) = liquidator.auctionInfo(
            address(proxy),
            0
        );
        (uint256 vaultPriceBefore, , bool forSaleBefore) = liquidator
            .getPriceOfVault(address(proxy), 0);

        vm.roll(block.number + blocksToRoll);
        (uint256 vaultPriceAfter, , bool forSaleAfter) = liquidator
            .getPriceOfVault(address(proxy), 0);

        uint256 expectedPrice = ((openDebt * liqThres) / 100) -
            ((blocksToRoll * ((openDebt * (liqThres - 100)) / 100)) /
                (liquidator.hourlyBlocks() * breakevenTime));

        emit log_named_uint("expectedPrice", expectedPrice);

        assertTrue(forSaleBefore);
        assertTrue(forSaleAfter);
        assertGe(vaultPriceBefore, vaultPriceAfter);
        assertEq(vaultPriceAfter, expectedPrice);
    }

    function getBalances(Stable stableAddr, address _vaultOwner)
        public
        view
        returns (Balances memory)
    {
        Balances memory bal;
        bal.keeper = stableAddr.balanceOf(address(1110));
        bal.protocol = stableAddr.balanceOf(address(1000));
        bal.originalOwner = stableAddr.balanceOf(_vaultOwner);

        return bal;
    }

    function getRewards(uint256 buyPrice, uint256 openDebt)
        public
        view
        returns (Rewards memory)
    {
        (uint64 protocolRatio, uint64 keeperRatio) = liquidator.claimRatio();

        Rewards memory rewards;
        rewards.expectedKeeperReward = (openDebt * keeperRatio) / 100;

        if (buyPrice > openDebt + rewards.expectedKeeperReward) {
            if (
                buyPrice - openDebt - rewards.expectedKeeperReward >
                (openDebt * protocolRatio) / 100
            ) {
                rewards.expectedProtocolReward =
                    (openDebt * protocolRatio) /
                    100;
                rewards.originalOwnerRecovery =
                    buyPrice -
                    openDebt -
                    rewards.expectedKeeperReward -
                    rewards.expectedProtocolReward;
            } else {
                rewards.expectedProtocolReward =
                    buyPrice -
                    openDebt -
                    rewards.expectedKeeperReward;
                rewards.originalOwnerRecovery = 0;
            }
        } else {
            rewards.expectedProtocolReward = 0;
            rewards.originalOwnerRecovery = 0;
        }

        return rewards;
    }

    function setAddresses() public {
        vm.startPrank(creatorAddress);
        liquidator.setProtocolTreasury(address(1000));
        liquidator.setReserveFund(address(1111));
        vm.stopPrank();
    }

    function setLife(Vault vaultAddr, uint256 newLife) public {
        uint256 slot = stdstore
            .target(address(vaultAddr))
            .sig(vaultAddr.life.selector)
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 newLife_b = bytes32(abi.encode(newLife));
        vm.store(address(vaultAddr), loc, newLife_b);
    }

    function giveStable(address addr, uint256 amount) public {
        uint256 slot = stdstore
            .target(address(stable))
            .sig(stable.balanceOf.selector)
            .with_key(addr)
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 newBalance = bytes32(abi.encode(amount));
        vm.store(address(stable), loc, newBalance);
    }

    function depositERC20InVault(
        ERC20Mock token,
        uint128 amount,
        address sender
    )
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC721InVault(
        ERC721Mock token,
        uint128[] memory tokenIds,
        address sender
    )
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC1155InVault(
        ERC1155Mock token,
        uint256 tokenId,
        uint256 amount,
        address sender
    )
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetTypes = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;
        assetTypes[0] = 2;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }
}
