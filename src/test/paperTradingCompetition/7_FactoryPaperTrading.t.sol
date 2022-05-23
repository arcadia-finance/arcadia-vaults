// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../7_Factory.t.sol";
import "../../OracleHub.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../paperTradingCompetition/Oracles/StableOracle.sol";
import "../../paperTradingCompetition/TokenShop.sol";




contract FactoryPaperTradingInheritedTest is factoryTest {

  OracleHub private oracleHub;
  StandardERC20Registry private standardERC20Registry;

  StablePaperTrading private stableUsd;
  StableOracle private oracleStableUsdToUsd;

  address[] public oracleStableUsdToUsdArr = new address[](1);

  constructor() factoryTest() {
    factoryContr = new FactoryPaperTrading();
    stableUsd = new StablePaperTrading("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factoryContr));
    vaultContr = new VaultPaperTrading();

    liquidatorContr = new Liquidator(address(factoryContr), 0x0000000000000000000000000000000000000000);
		registryContr = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
    
    oracleStableUsdToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "masUSD / USD");
    oracleHub = new OracleHub();
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'masUSD', baseAsset:'USD', oracleAddress:address(oracleStableUsdToUsd), quoteAssetAddress:address(stableUsd), baseAssetIsNumeraire: true}));
    standardERC20Registry = new StandardERC20Registry(address(registryContr), address(oracleHub));
    registryContr.addSubRegistry(address(standardERC20Registry));
    oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableUsdToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stableUsd)}), emptyList);


    factoryContr.setNewVaultInfo(address(registryContr), address(vaultContr), 0x0000000000000000000000000000000000000000, address(interestContr));
    factoryContr.confirmNewVaultInfo();
    factoryContr.setLiquidator(address(liquidatorContr));

    registryContr.setFactory(address(factoryContr));
  }

  //Test addNumeraire
  function testOldRegistryAddsNumeraire(address newNumeraire) public override {
		registryContr2 = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
    factoryContr.setNewVaultInfo(address(registryContr2), address(vaultContr), 0x0000000000000000000000000000000000000000, address(interestContr));
    factoryContr.confirmNewVaultInfo();
    registryContr2.setFactory(address(factoryContr));

    vm.expectRevert("FTRY_AN: Add Numeraires via MR");
		registryContr.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newNumeraire, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
  }

  function testLatestRegistryAddsNumeraire(address newStable) public override {
    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));	
    assertEq(address(0), factoryContr.numeraireToStable(1));	
		registryContr.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newStable, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(newStable, factoryContr.numeraireToStable(1));	 
  }  

  //Test setNewVaultInfo
  function testOwnerSetsNewVaultWithInfoMissingNumeraireInMainRegistry(address newStable, address logic, address stakeContract, address interestModule) public override {
    vm.assume(newStable != address(0));
    
		registryContr.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newStable, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(newStable, factoryContr.numeraireToStable(1));

    registryContr2 = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
    vm.expectRevert("FTRY_SNVI:No match numeraires MR");
    factoryContr.setNewVaultInfo(address(registryContr2), logic, stakeContract, interestModule);
  }

  function testOwnerSetsNewVaultWithIdenticalNumerairesInMainRegistry(address newStable, address logic, address stakeContract, address interestModule) public override {
		registryContr.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newStable, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(newStable, factoryContr.numeraireToStable(1));

    registryContr2 = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
		registryContr2.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newStable, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
    factoryContr.setNewVaultInfo(address(registryContr2), logic, stakeContract, interestModule);
    factoryContr.confirmNewVaultInfo();
    registryContr2.setFactory(address(factoryContr));

    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(newStable, factoryContr.numeraireToStable(1));  
  }

  function testOwnerSetsNewVaultWithMoreNumerairesInMainRegistry(address newStable, address logic, address stakeContract, address interestModule) public override {
    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(address(0), factoryContr.numeraireToStable(1));

    registryContr2 = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
		registryContr2.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:newStable, numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
    factoryContr.setNewVaultInfo(address(registryContr2), logic, stakeContract, interestModule);
    factoryContr.confirmNewVaultInfo();
    registryContr2.setFactory(address(factoryContr));

    assertEq(address(stableUsd), factoryContr.numeraireToStable(0));
    assertEq(newStable, factoryContr.numeraireToStable(1));  
  }

}

contract FactoryPaperTradingNewTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  MainRegistry private mainRegistry;
  FactoryPaperTrading internal factoryContr;
  StablePaperTrading private stableUsd;
  TokenShop private tokenShop;

  address private creatorAddress = address(1);

  constructor() {
    vm.startPrank(creatorAddress);
    factoryContr = new FactoryPaperTrading();
    stableUsd = new StablePaperTrading("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factoryContr));
    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));
    tokenShop = new TokenShop(address(mainRegistry));
    vm.stopPrank();
  }

  function testNonOwnerSetsTokenShop(address unprivilegedAddress) public {
    vm.assume(unprivilegedAddress != creatorAddress);
    vm.startPrank(unprivilegedAddress);
    vm.expectRevert("Ownable: caller is not the owner");
    factoryContr.setTokenShop(address(tokenShop));
    vm.stopPrank();
  }

  function testOwnerSetsTokenShop() public {
    vm.startPrank(creatorAddress);
    factoryContr.setTokenShop(address(tokenShop));
    vm.stopPrank();
  }

}