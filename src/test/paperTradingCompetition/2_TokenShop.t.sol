// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/stdlib.sol";
import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Vm.sol";

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../Proxy.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";
import "../../paperTradingCompetition/Oracles/StableOracle.sol";
import "../../mockups/SimplifiedChainlinkOracle.sol";

contract TokenShopTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  FactoryPaperTrading private factory;
  VaultPaperTrading private vault;
  VaultPaperTrading private proxy;
  address private proxyAddr;
  ERC20PaperTrading private eth;
  OracleHub private oracleHub;
  SimplifiedChainlinkOracle private oracleEthToUsd;
  StableOracle private oracleStableUsdToUsd;
  StableOracle private oracleStableEthToEth;
  MainRegistry private mainRegistry;
  StandardERC20Registry private standardERC20Registry;
  InterestRateModule private interestRateModule;
  StablePaperTrading private stableUsd;
  StablePaperTrading private stableEth;
  Liquidator private liquidator;

  address private creatorAddress = address(1);
  address private tokenCreatorAddress = address(2);
  address private oracleOwner = address(3);
  address private unprivilegedAddress = address(4);
  address private stakeContract = address(5);
  address private vaultOwner = address(6);

  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleStableUsdToUsdArr = new address[](1);
  address[] public oracleStableEthToUsdArr = new address[](2);

  //this is a before
  constructor() {

    vm.prank(tokenCreatorAddress);
    eth = new ERC20PaperTrading("ETH Mock", "mETH", uint8(Constants.ethDecimals), 0x0000000000000000000000000000000000000000);

    vm.startPrank(oracleOwner);
    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableUsdToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "masUSD / USD");
    oracleStableEthToEth = new StableOracle(uint8(Constants.oracleStableEthToEthUnit), "masEth / Eth");
    vm.stopPrank();

    vm.startPrank(creatorAddress);
    factory = new FactoryPaperTrading();
    stableUsd = new StablePaperTrading("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    stableEth = new StablePaperTrading("Arcadia ETH Stable Mock", "masETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    liquidator = new Liquidator(0x0000000000000000000000000000000000000000, address(mainRegistry), address(stableUsd));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(eth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableEth), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    oracleHub = new OracleHub();

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ETH', baseAsset:'USD', oracleAddress:address(oracleEthToUsd), quoteAssetAddress:address(eth), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'masUSD', baseAsset:'USD', oracleAddress:address(oracleStableUsdToUsd), quoteAssetAddress:address(stableUsd), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleStableEthToEthUnit), baseAssetNumeraire: 1, quoteAsset:'masETH', baseAsset:'ETH', oracleAddress:address(oracleStableEthToEth), quoteAssetAddress:address(stableEth), baseAssetIsNumeraire: true}));

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);
    oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
    oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(eth)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableUsdToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stableUsd)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableEthToUsdArr, assetUnit: uint64(10**Constants.stableEthDecimals), assetAddress: address(stableEth)}), emptyList);

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 ** 16);

    vault = new VaultPaperTrading();
    factory.setNewVaultInfo(address(mainRegistry), address(vault), stakeContract, address(interestRateModule));
    factory.confirmNewVaultInfo();
    factory.setLiquidator(address(liquidator));
    factory.setTokenShop(address(0));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));

    vm.stopPrank();

  }

  //this is a before each
  function setUp() public {

  }

  function testUsdVault() public {
    vm.prank(vaultOwner);
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))), Constants.UsdNumeraire);
    proxy = VaultPaperTrading(proxyAddr);

    uint256 expectedValue = 1000000 * Constants.WAD;
		uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

    assertEq(actualValue, expectedValue);
  }

  function testEthVault() public {
    vm.prank(vaultOwner);
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))), Constants.EthNumeraire);
    proxy = VaultPaperTrading(proxyAddr);

    uint256 expectedValue = 1000000 * Constants.WAD;
		uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

    assertEq(actualValue, expectedValue);
  }

}
