// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../lib/forge-std/src/stdlib.sol";
import "../../lib/forge-std/src/console.sol";
import "../../lib/forge-std/src/Vm.sol";

import "../Factory.sol";
import "../Proxy.sol";
import "../Vault.sol";
import "../tests/ERC20NoApprove.sol";
import "../tests/ERC721NoApprove.sol";
import "../tests/ERC1155NoApprove.sol";
import "../Stable.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/TestERC1155SubRegistry.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";
import "../OracleHub.sol";
import "../tests/SimplifiedChainlinkOracle.sol";
import "../utils/Constants.sol";

contract GasBenchMark is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  Factory private factory;
  Vault private vault;
  Vault private proxy;
  address private proxyAddr;
  ERC20NoApprove private eth;
  ERC20NoApprove private snx;
  ERC20NoApprove private link;
  ERC20NoApprove private safemoon;
  ERC721NoApprove private bayc;
  ERC721NoApprove private mayc;
  ERC721NoApprove private dickButs;
  ERC20NoApprove private wbayc;
  ERC20NoApprove private wmayc;
  ERC1155NoApprove private interleave;
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
  TestERC1155SubRegistry private testERC1155SubRegistry;
  InterestRateModule private interestRateModule;
  Stable private stable;
  Liquidator private liquidator;

  address private creatorAddress = address(1);
  address private tokenCreatorAddress = address(2);
  address private oracleOwner = address(3);
  address private unprivilegedAddress = address(4);
  address private stakeContract = address(5);
  address private vaultOwner = address(6);


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

  //this is a before
  constructor() {
    vm.startPrank(tokenCreatorAddress);

    eth = new ERC20NoApprove(uint8(Constants.ethDecimals));
    eth.mint(tokenCreatorAddress, 200000 * 10**Constants.ethDecimals);

    snx = new ERC20NoApprove(uint8(Constants.snxDecimals));
    snx.mint(tokenCreatorAddress, 200000 * 10**Constants.snxDecimals);

    link = new ERC20NoApprove(uint8(Constants.linkDecimals));
    link.mint(tokenCreatorAddress, 200000 * 10**Constants.linkDecimals);

    safemoon = new ERC20NoApprove(uint8(Constants.safemoonDecimals));
    safemoon.mint(tokenCreatorAddress, 200000 * 10**Constants.safemoonDecimals);

    bayc = new ERC721NoApprove();
    bayc.mint(tokenCreatorAddress, 0);
    bayc.mint(tokenCreatorAddress, 1);
    bayc.mint(tokenCreatorAddress, 2);
    bayc.mint(tokenCreatorAddress, 3);

    mayc = new ERC721NoApprove();
    mayc.mint(tokenCreatorAddress, 0);

    dickButs = new ERC721NoApprove();
    dickButs.mint(tokenCreatorAddress, 0);

    wbayc = new ERC20NoApprove(uint8(Constants.wbaycDecimals));
    wbayc.mint(tokenCreatorAddress, 100000 * 10**Constants.wbaycDecimals);

    interleave = new ERC1155NoApprove("ERC1155 No Appr", "1155NAP");
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

    oracleEthToUsd.setAnswer(int256(rateEthToUsd));
    oracleLinkToUsd.setAnswer(int256(rateLinkToUsd));
    oracleSnxToEth.setAnswer(int256(rateSnxToEth));
    oracleWbaycToEth.setAnswer(int256(rateWbaycToEth));
    oracleWmaycToUsd.setAnswer(int256(rateWmaycToUsd));
    oracleInterleaveToEth.setAnswer(int256(rateInterleaveToEth));
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
    stable = new Stable(uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000);
    stable.mint(tokenCreatorAddress, 100000 * 10 ** Constants.stableDecimals);
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

    vm.startPrank(creatorAddress);
    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, numeraireLabel:'USD', numeraireUnit:1}));
    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(eth), numeraireToUsdOracle:address(oracleEthToUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    floorERC721SubRegistry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    testERC1155SubRegistry = new TestERC1155SubRegistry(address(mainRegistry), address(oracleHub));

    mainRegistry.addSubRegistry(address(standardERC20Registry));
    mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
    mainRegistry.addSubRegistry(address(testERC1155SubRegistry));

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

    vm.prank(tokenCreatorAddress);
    stable.setLiquidator(address(liquidator));

    vm.startPrank(creatorAddress);
    factory = new Factory();
    factory.setVaultInfo(1, address(mainRegistry), address(vault), address(stable), stakeContract, address(interestRateModule));
   factory.setVaultVersion(1);
factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));
    vm.stopPrank();

    vm.prank(vaultOwner);
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))));
    proxy = Vault(proxyAddr);

    vm.startPrank(oracleOwner);
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));
    oracleLinkToUsd.setAnswer(int256(rateLinkToUsd));
    oracleSnxToEth.setAnswer(int256(rateSnxToEth));
    oracleWbaycToEth.setAnswer(int256(rateWbaycToEth));
    oracleWmaycToUsd.setAnswer(int256(rateWmaycToUsd));
    oracleInterleaveToEth.setAnswer(int256(rateInterleaveToEth));
    vm.stopPrank();
  }

  function testCreateProxyVault() public {
    address proxyAddrNew; //avoid storage gas cost
    vm.roll(1); //increase block for random salt
    uint256 salt = uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number))));
    vm.startPrank(vaultOwner);
    uint256 gasBefore = gasleft();
    proxyAddrNew = factory.createVault(salt);
    uint256 gasAfter = gasleft();
    vm.stopPrank();

    emit log_named_uint("Proxy deploy", gasBefore-gasAfter);
  }

  function testDepositERC20InVault() public {
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

    vm.prank(tokenCreatorAddress);
    eth.mint(vaultOwner, 1e18);

    vm.startPrank(vaultOwner);
    uint256 gasBefore = gasleft();
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    uint256 gasAfter = gasleft();
    emit log_named_uint("Deposit ERC20 gas usage", gasBefore - gasAfter);
    vm.stopPrank();
  }

  function testDepositTwoERC20InVault() public {
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

    vm.startPrank(tokenCreatorAddress);
    eth.mint(vaultOwner, 100e18);
    link.mint(vaultOwner, 100e18);
    eth.mint(unprivilegedAddress, 1e18);
    link.mint(unprivilegedAddress, 1e18);
    vm.stopPrank();

    vm.startPrank(vaultOwner);
    uint256 gasBefore = gasleft();
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    uint256 gasAfter = gasleft();
    emit log_named_uint("Deposit ERC20 gas usage", gasBefore - gasAfter);
    
    uint256 gasBeforeTransferBenchmarkEth = gasleft();
    eth.transferFrom(unprivilegedAddress, address(0), 10**Constants.ethDecimals);
    uint256 gasAfterTransferBenchmarkEth = gasleft();

        
    uint256 gasBeforeTransferBenchmarkLink = gasleft();
    link.transferFrom(unprivilegedAddress, address(0), 10**Constants.linkDecimals);
    uint256 gasAfterTransferBenchmarkLink = gasleft();


    uint256 overheadByContract = gasBefore - gasAfter - (gasBeforeTransferBenchmarkEth - gasAfterTransferBenchmarkEth) - (gasBeforeTransferBenchmarkLink - gasAfterTransferBenchmarkLink);
    emit log_named_uint("Overhead by contract", overheadByContract);
    emit log_named_uint("    Per deposit average", overheadByContract / assetAddresses.length);

    emit log_named_uint("    wETH transfer", gasBeforeTransferBenchmarkEth - gasAfterTransferBenchmarkEth);
    emit log_named_uint("    Link transfer", gasBeforeTransferBenchmarkLink - gasAfterTransferBenchmarkLink);

    vm.stopPrank();

  }

  function testDepositThreeERC20InVault() public {
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

    vm.startPrank(tokenCreatorAddress);
    eth.mint(vaultOwner, 100e18);
    link.mint(vaultOwner, 100e18);
    snx.mint(vaultOwner, 100e18);
    eth.mint(unprivilegedAddress, 1e18);
    link.mint(unprivilegedAddress, 1e18);
    snx.mint(unprivilegedAddress, 1e18);
    vm.stopPrank();

    vm.startPrank(vaultOwner);
    uint256 gasBefore = gasleft();
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    uint256 gasAfter = gasleft();
    emit log_named_uint("Deposit ERC20 gas usage", gasBefore - gasAfter);
    
    uint256 gasBeforeTransferBenchmarkEth = gasleft();
    eth.transferFrom(unprivilegedAddress, address(0), 10**Constants.ethDecimals);
    uint256 gasAfterTransferBenchmarkEth = gasleft();

        
    uint256 gasBeforeTransferBenchmarkLink = gasleft();
    link.transferFrom(unprivilegedAddress, address(0), 10**Constants.linkDecimals);
    uint256 gasAfterTransferBenchmarkLink = gasleft();

    uint256 gasBeforeTransferBenchmarkSnx = gasleft();
    snx.transferFrom(unprivilegedAddress, address(0), 10**Constants.snxDecimals);
    uint256 gasAfterTransferBenchmarkSnx = gasleft();


    uint256 overheadByContract = gasBefore - gasAfter 
                               - (gasBeforeTransferBenchmarkEth - gasAfterTransferBenchmarkEth) 
                               - (gasBeforeTransferBenchmarkLink - gasAfterTransferBenchmarkLink)
                               - (gasBeforeTransferBenchmarkSnx - gasAfterTransferBenchmarkSnx);

    emit log_named_uint("Overhead by contract", overheadByContract);
    emit log_named_uint("    Per deposit average", overheadByContract / assetAddresses.length);

    emit log_named_uint("    wETH transfer", gasBeforeTransferBenchmarkEth - gasAfterTransferBenchmarkEth);
    emit log_named_uint("    Link transfer", gasBeforeTransferBenchmarkLink - gasAfterTransferBenchmarkLink);
    emit log_named_uint("    Snx transfer", gasBeforeTransferBenchmarkSnx - gasAfterTransferBenchmarkSnx);

    vm.stopPrank();

  }

  function testGetValue1ERC20() public {
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

    vm.prank(tokenCreatorAddress);
    eth.mint(vaultOwner, 1e18);

    vm.startPrank(vaultOwner);
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    vm.stopPrank();

    uint256 gasBefore = gasleft();
    proxy.getValue(uint8(Constants.UsdNumeraire));
    uint256 gasAfter = gasleft();
    emit log_named_uint("GetValue 1 ERC20", gasBefore - gasAfter);

  }

  function testGetValue3ERC20() public {
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

    vm.startPrank(tokenCreatorAddress);
    eth.mint(vaultOwner, 100e18);
    link.mint(vaultOwner, 100e18);
    snx.mint(vaultOwner, 100e18);
    eth.mint(unprivilegedAddress, 1e18);
    link.mint(unprivilegedAddress, 1e18);
    snx.mint(unprivilegedAddress, 1e18);
    vm.stopPrank();

    vm.startPrank(vaultOwner);
    proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    vm.stopPrank();

    uint256 gasBefore = gasleft();
    proxy.getValue(uint8(Constants.UsdNumeraire));
    uint256 gasAfter = gasleft();
    emit log_named_uint("GetValue 3 ERC20", gasBefore - gasAfter);
  }



}
