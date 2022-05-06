// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../lib/forge-std/src/stdlib.sol";
import "../../lib/forge-std/src/console.sol";
import "../../lib/forge-std/src/Vm.sol";

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
import "../AssetRegistry/floorERC1155SubRegistry.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";
import "../OracleHub.sol";
import "../mockups/SimplifiedChainlinkOracle.sol";
import "../utils/Constants.sol";

contract LiquidatorTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

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
  OracleHub private oracleHub;
  SimplifiedChainlinkOracle private oracleEthToUsd;
  SimplifiedChainlinkOracle private oracleLinkToUsd;
  SimplifiedChainlinkOracle private oracleSnxToEth;
  SimplifiedChainlinkOracle private oracleWbaycToEth;
  SimplifiedChainlinkOracle private oracleWmaycToUsd;
  SimplifiedChainlinkOracle private oracleInterleaveToEth;
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
  address private auctionBuyer = address(8);


  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;
  uint256 rateLinkToUsd = 20 * 10 ** Constants.oracleLinkToUsdDecimals;
  uint256 rateSnxToEth = 1600000000000000;
  uint256 rateWbaycToEth = 85 * 10 ** Constants.oracleWbaycToEthDecimals;
  uint256 rateWmaycToUsd = 50000 * 10 ** Constants.oracleWmaycToUsdDecimals;
  uint256 rateInterleaveToEth = 1 * 10 ** (Constants.oracleInterleaveToEthDecimals - 2);

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleLinkToUsdArr = new address[](1);
  address[] public oracleSnxToEthEthToUsd = new address[](2);
  address[] public oracleWbaycToEthEthToUsd = new address[](2);
  address[] public oracleWmaycToUsdArr = new address[](1);
  address[] public oracleInterleaveToEthEthToUsd = new address[](2);


  // EVENTS
  event Transfer(address indexed from, address indexed to, uint256 amount);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  //this is a before
  constructor() {
    vm.startPrank(tokenCreatorAddress);

    eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
    eth.mint(tokenCreatorAddress, 200000 * 10**Constants.ethDecimals);

    snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
    snx.mint(tokenCreatorAddress, 200000 * 10**Constants.snxDecimals);

    link = new ERC20Mock("LINK Mock", "mLINK", uint8(Constants.linkDecimals));
    link.mint(tokenCreatorAddress, 200000 * 10**Constants.linkDecimals);

    safemoon = new ERC20Mock("Safemoon Mock", "mSFMN", uint8(Constants.safemoonDecimals));
    safemoon.mint(tokenCreatorAddress, 200000 * 10**Constants.safemoonDecimals);

    bayc = new ERC721Mock("BAYC Mock", "mBAYC");
    bayc.mint(tokenCreatorAddress, 0);
    bayc.mint(tokenCreatorAddress, 1);
    bayc.mint(tokenCreatorAddress, 2);
    bayc.mint(tokenCreatorAddress, 3);

    mayc = new ERC721Mock("MAYC Mock", "mMAYC");
    mayc.mint(tokenCreatorAddress, 0);

    dickButs = new ERC721Mock("DickButs Mock", "mDICK");
    dickButs.mint(tokenCreatorAddress, 0);

    wbayc = new ERC20Mock("wBAYC Mock", "mwBAYC", uint8(Constants.wbaycDecimals));
    wbayc.mint(tokenCreatorAddress, 100000 * 10**Constants.wbaycDecimals);

    interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
    interleave.mint(tokenCreatorAddress, 1, 100000);

    vm.stopPrank();

    vm.prank(creatorAddress);
    oracleHub = new OracleHub();

    vm.startPrank(oracleOwner);
    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleLinkToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleLinkToUsdDecimals), "LINK / USD");
    oracleSnxToEth = new SimplifiedChainlinkOracle(uint8(Constants.oracleSnxToEthDecimals), "SNX / ETH");
    oracleWbaycToEth = new SimplifiedChainlinkOracle(uint8(Constants.oracleWbaycToEthDecimals), "WBAYC / ETH");
    oracleWmaycToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleWmaycToUsdDecimals), "WMAYC / USD");
    oracleInterleaveToEth = new SimplifiedChainlinkOracle(uint8(Constants.oracleInterleaveToEthDecimals), "INTERLEAVE / ETH");
    vm.stopPrank();

    vm.startPrank(creatorAddress);
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ETH', baseAsset:'USD', oracleAddress:address(oracleEthToUsd), quoteAssetAddress:address(eth), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleLinkToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LINK', baseAsset:'USD', oracleAddress:address(oracleLinkToUsd), quoteAssetAddress:address(link), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleSnxToEthUnit), baseAssetNumeraire: 1, quoteAsset:'SNX', baseAsset:'ETH', oracleAddress:address(oracleSnxToEth), quoteAssetAddress:address(snx), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleWbaycToEthUnit), baseAssetNumeraire: 1, quoteAsset:'WBAYC', baseAsset:'ETH', oracleAddress:address(oracleWbaycToEth), quoteAssetAddress:address(wbayc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleWmaycToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'WMAYC', baseAsset:'USD', oracleAddress:address(oracleWmaycToUsd), quoteAssetAddress:address(wmayc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleInterleaveToEthUnit), baseAssetNumeraire: 1, quoteAsset:'INTERLEAVE', baseAsset:'ETH', oracleAddress:address(oracleInterleaveToEth), quoteAssetAddress:address(interleave), baseAssetIsNumeraire: true}));
    vm.stopPrank();

    vm.startPrank(tokenCreatorAddress);
    eth.transfer(vaultOwner, 100000 * 10 ** Constants.ethDecimals);
    link.transfer(vaultOwner, 100000 * 10 ** Constants.linkDecimals);
    snx.transfer(vaultOwner, 100000 * 10 ** Constants.snxDecimals);
    safemoon.transfer(vaultOwner, 100000 * 10 ** Constants.safemoonDecimals);
    bayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
    bayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
    bayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
    bayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
    mayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
    dickButs.transferFrom(tokenCreatorAddress, vaultOwner, 0);
    interleave.safeTransferFrom(tokenCreatorAddress, vaultOwner, 1, 100000, '0x0000000000000000000000000000000000000000000000000000000000000000');
    eth.transfer(unprivilegedAddress, 1000 * 10 ** Constants.ethDecimals);
    vm.stopPrank();

    vm.startPrank(creatorAddress);
    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 ** 16);
    vm.stopPrank();

    vm.startPrank(tokenCreatorAddress);
    stable = new Stable("Arcadia Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
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
  function setUp() public {

    emit log_named_address("oracleEthToUsdArr[0]", oracleEthToUsdArr[0]);

    vm.startPrank(creatorAddress);
    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, numeraireLabel:'USD', numeraireUnit:1}));
    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(eth), numeraireToUsdOracle:address(oracleEthToUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    floorERC721SubRegistry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    floorERC1155SubRegistry = new FloorERC1155SubRegistry(address(mainRegistry), address(oracleHub));

    mainRegistry.addSubRegistry(address(standardERC20Registry));
    mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
    mainRegistry.addSubRegistry(address(floorERC1155SubRegistry));

    uint256[] memory assetCreditRatings = new uint256[](2);
    assetCreditRatings[0] = 0;
    assetCreditRatings[1] = 0;

    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(eth)}), assetCreditRatings);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleLinkToUsdArr, assetUnit: uint64(10**Constants.linkDecimals), assetAddress: address(link)}), assetCreditRatings);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleSnxToEthEthToUsd, assetUnit: uint64(10**Constants.snxDecimals), assetAddress: address(snx)}), assetCreditRatings);

    floorERC721SubRegistry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: oracleWbaycToEthEthToUsd, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: address(bayc)}), assetCreditRatings);

    liquidator = new Liquidator(0x0000000000000000000000000000000000000000, address(mainRegistry), address(stable));
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
    factory.setVaultInfo(1, address(mainRegistry), address(vault), address(stable), stakeContract, address(interestRateModule));
    factory.setVaultVersion(1);
    factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));
    vm.stopPrank();

    vm.startPrank(tokenCreatorAddress);
    stable.setFactory(address(factory));
    vm.stopPrank();

    vm.prank(vaultOwner);
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))));
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
    stable.mint(tokenCreatorAddress, 100000 * 10 ** Constants.stableDecimals);

    vm.startPrank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));
    oracleLinkToUsd.setAnswer(int256(rateLinkToUsd));
    oracleSnxToEth.setAnswer(int256(rateSnxToEth));
    oracleWbaycToEth.setAnswer(int256(rateWbaycToEth));
    oracleWmaycToUsd.setAnswer(int256(rateWmaycToUsd));
    oracleInterleaveToEth.setAnswer(int256(rateInterleaveToEth));
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

  function testNotAllowAuctionHealthyVault(uint128 amountEth, uint128 amountCredit) public {
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);
    vm.assume(valueOfOneEth * amountEth/10**Constants.ethDecimals / 150 * 100 >= amountCredit);
    depositERC20InVault(eth, amountEth, vaultOwner);

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.startPrank(liquidatorBot);
    vm.expectRevert("This vault is healthy");
    factory.liquidate(address(proxy));
    vm.stopPrank();

    assertEq(proxy.life(), 0);
  }  

  function testStartAuction(uint128 amountEth, uint256 newPrice) public {
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);
    depositERC20InVault(eth, amountEth, vaultOwner);
    assertEq(proxy.life(), 0);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.startPrank(liquidatorBot);
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(vaultOwner,address(liquidator));
    factory.liquidate(address(proxy));
    vm.stopPrank();

    assertEq(proxy.life(), 1);
  }  


  function testShowVaultAuctionPrice(uint128 amountEth, uint256 newPrice) public {
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    depositERC20InVault(eth, amountEth, vaultOwner);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.prank(liquidatorBot);
    factory.liquidate(address(proxy));

    (,,uint8 liqThres,,,) = liquidator.auctionInfo(address(proxy), 0);

    (uint256 vaultPrice, bool forSale) = liquidator.getPriceOfVault(address(proxy), 0);

    uint256 expectedPrice = amountCredit * liqThres / 100;
    assertTrue(forSale);
    assertEq(vaultPrice, expectedPrice);

  }

  function testAuctionPriceDecrease(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
    vm.assume(blocksToRoll < liquidator.hourlyBlocks() * liquidator.auctionDuration());
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    depositERC20InVault(eth, amountEth, vaultOwner);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.prank(liquidatorBot);
    factory.liquidate(address(proxy));

    (uint128 openDebt,, uint8 liqThres,,,) = liquidator.auctionInfo(address(proxy), 0);
    (uint256 vaultPriceBefore, bool forSaleBefore) = liquidator.getPriceOfVault(address(proxy), 0);

    vm.roll(blocksToRoll);
    (uint256 vaultPriceAfter, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy), 0);

    uint256 expectedPrice = (openDebt * liqThres /100)  - (blocksToRoll * (openDebt * (liqThres-100)/100) /(liquidator.hourlyBlocks() * liquidator.auctionDuration()));

    emit log_named_uint("expectedPrice", expectedPrice);

    assertTrue(forSaleBefore);
    assertTrue(forSaleAfter);
    assertGe(vaultPriceBefore, vaultPriceAfter);
    assertEq(vaultPriceAfter, expectedPrice);

  }

  function testStopSaleAfterAuctionDuration(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
    vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.auctionDuration());
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    depositERC20InVault(eth, amountEth, vaultOwner);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.prank(liquidatorBot);
    factory.liquidate(address(proxy));

    vm.roll(blocksToRoll);
    (, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy), 0);

    assertTrue(!forSaleAfter);

  }

  function testBuyVault(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
    vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.auctionDuration());
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    depositERC20InVault(eth, amountEth, vaultOwner);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.prank(liquidatorBot);
    factory.liquidate(address(proxy));

    (uint256 priceOfVault,) = liquidator.getPriceOfVault(address(proxy), 0);
    vm.prank(address(proxy));
    stable.mint(auctionBuyer, priceOfVault);

    vm.prank(auctionBuyer);
    liquidator.buyVault(address(proxy), 0);

    assertEq(proxy.owner(), auctionBuyer); //todo: check erc721 owner

  }

  function testWithrawAssetsFromPurchasedVault(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
    vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.auctionDuration());
    (, uint16 collThresProxy, uint8 liqThresProxy,,,) = proxy.debt();
    vm.assume(newPrice/ liqThresProxy  < rateEthToUsd / collThresProxy);
    vm.assume(amountEth > 0);
    uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    (address[] memory assetAddresses,
    uint256[] memory assetIds,
    uint256[] memory assetAmounts,
    uint256[] memory assetTypes) = depositERC20InVault(eth, amountEth, vaultOwner);

    uint128 amountCredit = uint128(proxy.getRemainingCredit());

    vm.prank(vaultOwner);
    proxy.takeCredit(amountCredit);

    vm.prank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(newPrice));

    vm.prank(liquidatorBot);
    factory.liquidate(address(proxy));

    (uint256 priceOfVault,) = liquidator.getPriceOfVault(address(proxy), 0);
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






  function depositERC20InVault(ERC20Mock token, uint128 amount, address sender) public returns (address[] memory assetAddresses,
                                                              uint256[] memory assetIds,
                                                              uint256[] memory assetAmounts,
                                                              uint256[] memory assetTypes) {

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

  function depositERC721InVault(ERC721Mock token, uint128[] memory tokenIds, address sender) public returns (address[] memory assetAddresses,
                                                              uint256[] memory assetIds,
                                                              uint256[] memory assetAmounts,
                                                              uint256[] memory assetTypes) {
    assetAddresses = new address[](tokenIds.length);
    assetIds = new uint256[](tokenIds.length);
    assetAmounts = new uint256[](tokenIds.length);
    assetTypes = new uint256[](tokenIds.length);

    uint tokenIdToWorkWith;
    for (uint i; i < tokenIds.length; i++) {
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

  function depositERC1155InVault(ERC1155Mock token, uint256 tokenId, uint256 amount, address sender) 
                                              public returns (address[] memory assetAddresses,
                                                              uint256[] memory assetIds,
                                                              uint256[] memory assetAmounts,
                                                              uint256[] memory assetTypes) {

    assetAddresses = new address[](1);
    assetIds = new uint256[](1);
    assetAmounts = new uint256[](1);
    assetTypes = new uint256[](1);

    token.mint(sender, tokenId, amount);
    assetAddresses[0] = address(token);
    assetIds[0] = tokenId;
    assetAmounts[0] =  amount;
    assetTypes[0] = 2;


    vm.startPrank(sender);
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    vm.stopPrank();
  }

}
