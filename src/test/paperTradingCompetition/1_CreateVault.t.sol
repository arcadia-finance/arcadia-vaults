// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/stdlib.sol";
import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Vm.sol";

import "../../Factory.sol";
import "../../Proxy.sol";
import "../../Vault.sol";
import "../../Stable.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../mockups/ERC20SolmateMock.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";
import "../../Oracles/StableOracle.sol";
import "../../mockups/SimplifiedChainlinkOracle.sol";

contract CreateVaultTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  Factory private factory;
  Vault private vault;
  Vault private proxy;
  address private proxyAddr;
  ERC20Mock private eth;
  OracleHub private oracleHub;
  SimplifiedChainlinkOracle private oracleEthToUsd;
  StableOracle private oracleStableToUsd;
  MainRegistry private mainRegistry;
  StandardERC20Registry private standardERC20Registry;
  InterestRateModule private interestRateModule;
  Stable private stable;
  StableOracle private oracle;
  Liquidator private liquidator;

  address private creatorAddress = address(1);
  address private tokenCreatorAddress = address(2);
  address private oracleOwner = address(3);
  address private unprivilegedAddress = address(4);
  address private stakeContract = address(5);
  address private vaultOwner = address(6);

  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleStableToUsdArr = new address[](1);

  //this is a before
  constructor() {

    vm.prank(tokenCreatorAddress);
    eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));

    vm.startPrank(oracleOwner);
    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "STABLE / USD");
    vm.stopPrank();

    vm.startPrank(creatorAddress);
    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, numeraireLabel:'USD', numeraireUnit:1}));
    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(eth), numeraireToUsdOracle:address(oracleEthToUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    stable = new Stable("Arcadia Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000);
    liquidator = new Liquidator(0x0000000000000000000000000000000000000000, address(mainRegistry), address(stable));
    stable.setLiquidator(address(liquidator));

    oracleHub = new OracleHub();

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ETH', baseAsset:'USD', oracleAddress:address(oracleEthToUsd), quoteAssetAddress:address(eth), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'STABLE', baseAsset:'USD', oracleAddress:address(oracleStableToUsd), quoteAssetAddress:address(stable), baseAssetIsNumeraire: true}));

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableToUsdArr[0] = address(oracleStableToUsd);

    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(eth)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stable)}), emptyList);

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 ** 16);

    vault = new Vault();
    factory = new Factory();
    factory.setVaultInfo(1, address(mainRegistry), address(vault), address(stable), stakeContract, address(interestRateModule));
    factory.setVaultVersion(1);
    factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));

    vm.stopPrank();

  }

  //this is a before each
  function setUp() public {
    vm.prank(vaultOwner);
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))));
    proxy = Vault(proxyAddr);
  }

  function testExample() public {
    uint256 expectedValue = 1000000 * Constants.WAD;
		uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

    assertEq(actualValue, expectedValue);
  }

}
