/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../Proxy.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../utils/Constants.sol";
import "../../ArcadiaOracle.sol";

import "../../paperTradingCompetition/MainRegistryPaperTrading.sol";
import "../../paperTradingCompetition/LiquidatorPaperTrading.sol";
import "../../paperTradingCompetition/TokenShop.sol";

import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../paperTradingCompetition/ERC721PaperTrading.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../OracleHub.sol";

import "../../InterestRateModule.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/Script.sol";
import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Vm.sol";

import "../../utils/Constants.sol";
import "../../utils/Strings.sol";
import "../../utils/StringHelpers.sol";

import "./helper.sol";


contract DeployScript is DSTest, Script {


  FactoryPaperTrading public factory;
  Vault public vault;
  VaultPaperTrading public proxy;
  address public proxyAddr;
  
  OracleHub public oracleHub;
  MainRegistryPaperTrading public mainRegistry;
  StandardERC20Registry public standardERC20Registry;
  FloorERC721SubRegistry public floorERC721Registry;
  InterestRateModule public interestRateModule;
  StablePaperTrading public stableUsd;
  StablePaperTrading public stableEth;
  ArcadiaOracle public oracleStableUsdToUsd;
  ArcadiaOracle public oracleStableEthToEth;
  LiquidatorPaperTrading public liquidator;
  TokenShop public tokenShop;

  ERC20PaperTrading public weth;

  ArcadiaOracle public oracleEthToUsd;

  HelperContract public helper;

  address private creatorAddress = address(1);
  address private tokenCreatorAddress = address(2);
  address private oracleOwner = address(3);
  address private unprivilegedAddress = address(4);
  address private stakeContract = address(5);
  address private vaultOwner = address(6);

  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleStableToUsdArr = new address[](1);

  struct assetInfo {
    uint8 decimals;
    uint8 oracleDecimals;
    uint8 creditRatingUsd;
    uint8 creditRatingEth;
    uint128 rate;
    string desc;
    string symbol;
    string quoteAsset;
    string baseAsset;
    address oracleAddr;
    address assetAddr;
  }

  assetInfo[] public assets;


  constructor() {

  }

  function createNewVaultThroughDeployer(address newVaultOwner) public {
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))), 0);
    factory.safeTransferFrom(address(this), newVaultOwner, factory.vaultIndex(address(proxyAddr)));
  }
  
  function setOracleAnswer(address oracleAddr, uint256 amount) external {
    ArcadiaOracle(oracleAddr).transmit(int256(amount));
  }


  function run() public {
    vm.startBroadcast();
    factory = new FactoryPaperTrading();
    factory.setBaseURI("ipfs://");

    stableUsd = new StablePaperTrading("Mocked Arcadia USD", "maUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    stableEth = new StablePaperTrading("Mocked Arcadia ETH", "maETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory));

    mainRegistry = new MainRegistryPaperTrading(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));

    liquidator = new LiquidatorPaperTrading(address(factory), address(mainRegistry));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    tokenShop = new TokenShop(address(mainRegistry));
    tokenShop.setFactory(address(factory));
    weth = new ERC20PaperTrading("Mocked Wrapped ETH", "mETH", uint8(Constants.ethDecimals), address(tokenShop));

    oracleEthToUsd = new ArcadiaOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD", address(weth));
    oracleEthToUsd.setOffchainTransmitter(address(this));
    oracleEthToUsd.setOffchainTransmitter(msg.sender);
    oracleEthToUsd.setOffchainTransmitter(address(0xaaAaAAA3eA06C421c320903C77d8f1dde895690f));

    oracleEthToUsd.transmit(int256(rateEthToUsd));

    oracleStableUsdToUsd = new ArcadiaOracle(uint8(Constants.oracleStableToUsdDecimals), "maUSD / USD", address(stableUsd));
    oracleStableUsdToUsd.setOffchainTransmitter(msg.sender);
    oracleStableUsdToUsd.setOffchainTransmitter(address(this));
    oracleStableUsdToUsd. setOffchainTransmitter(address(0xaaAaAAA3eA06C421c320903C77d8f1dde895690f));
    oracleStableUsdToUsd.transmit(int256(Constants.oracleStableToUsdUnit));

    oracleStableEthToEth = new ArcadiaOracle(uint8(Constants.oracleStableEthToEthDecimals), "maETH / ETH", address(stableEth));
    oracleStableEthToEth.setOffchainTransmitter(msg.sender);
    oracleStableEthToEth.setOffchainTransmitter(address(this));
    oracleStableEthToEth.setOffchainTransmitter(address(0xaaAaAAA3eA06C421c320903C77d8f1dde895690f));
    oracleStableEthToEth.transmit(int256(Constants.oracleStableEthToEthUnit));

    stableUsd.setTokenShop(address(tokenShop));
    stableEth.setTokenShop(address(tokenShop));

    oracleHub = new OracleHub();

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(floorERC721Registry));

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(11 * 10**15); //1.1%
    uint256[] memory creditRatings = new uint256[](10);
    for (uint i; i < 10; ++i) {
      creditRatings[i] = i;
    }
    uint256[] memory interestRates = new uint256[](10);
    interestRates[0] = 12 * 10**16; //12%
    interestRates[1] = 0; //0%
    interestRates[2] = 5 * 10**15; //0.5%
    interestRates[3] = 75 * 10**14; //0.75%
    interestRates[4] = 12 * 10**15; //1.2%
    interestRates[5] = 16 * 10**15; //1.6%
    interestRates[6] = 25 * 10**15; //2.5%
    interestRates[7] = 4 * 10**16; //4%
    interestRates[8] = 6 * 10**16; //6%
    interestRates[9] = 9 * 10**16; //9%
    interestRateModule.batchSetCollateralInterestRates(creditRatings, interestRates);

    vault = new VaultPaperTrading();
    factory.setNewVaultInfo(address(mainRegistry), address(vault), stakeContract, address(interestRateModule));
    factory.confirmNewVaultInfo();
    factory.setLiquidator(address(liquidator));
    factory.setTokenShop(address(tokenShop));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));
    vm.stopBroadcast();

    storeAssets();


    deployERC20Contracts();
    deployERC721Contracts();
    deployOracles();
    setOracleAnswers();
    addOracles();
    setAssetInformation();

    vm.startBroadcast();
    helper = new HelperContract();
    helper.storeAddresses(HelperContract.HelperAddresses({
                          factory: address(factory),
                          vaultLogic: address(vault),
                          mainReg: address(mainRegistry),
                          erc20sub: address(standardERC20Registry),
                          erc721sub: address(floorERC721Registry),
                          oracleHub: address(oracleHub),
                          irm: address(interestRateModule),
                          liquidator: address(liquidator),
                          stableUsd: address(stableUsd),
                          stableEth: address(stableEth),
                          weth: address(weth),
                          tokenShop: address(tokenShop)}
                          ));
    vm.stopBroadcast();

    floorERC721Registry.getAssetInformation(assets[40].assetAddr);

  }

  function testall() public {
    run();
    helper.getAllPrices();
  }

  function deployERC20Contracts() public {
    vm.startBroadcast();
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (asset.decimals == 0) { }
      else {
        if (asset.assetAddr == address(0)) {
          newContr = address(new ERC20PaperTrading(asset.desc, asset.symbol, asset.decimals, address(tokenShop)));
          assets[i].assetAddr = newContr;
        }
       }
      
    }
    vm.stopBroadcast();
  }

  function deployERC721Contracts() public {
    vm.startBroadcast();
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (asset.decimals == 0) {
        newContr = address(new ERC721PaperTrading(asset.desc, asset.symbol, address(tokenShop)));
        assets[i].assetAddr = newContr;
      }
      else { }
      
    }
    vm.stopBroadcast();
  }

  function deployOracles() public {
    vm.startBroadcast();
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (!StringHelpers.compareStrings(asset.symbol, "mwETH")) {
        newContr = address(new ArcadiaOracle(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD")), asset.assetAddr));
        ArcadiaOracle(newContr).setOffchainTransmitter(address(this));
        ArcadiaOracle(newContr).setOffchainTransmitter(msg.sender);
        ArcadiaOracle(newContr).setOffchainTransmitter(address(0xaaAaAAA3eA06C421c320903C77d8f1dde895690f));
        assets[i].oracleAddr = newContr;
      }
    }

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableEth), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
    vm.stopBroadcast();

  }

  function setOracleAnswers() public {
    vm.startBroadcast();
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      ArcadiaOracle(asset.oracleAddr).transmit(int256(uint256(asset.rate)));
    }
    vm.stopBroadcast();
  }

  function addOracles() public {
    vm.startBroadcast();

    assetInfo memory asset;
    uint8 baseAssetNum;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (StringHelpers.compareStrings(asset.baseAsset, "ETH")) {
        baseAssetNum = 1;
      }
      else {
        baseAssetNum = 0;
      }
      oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(10**asset.oracleDecimals), baseAssetNumeraire: baseAssetNum, quoteAsset: asset.quoteAsset, baseAsset: asset.baseAsset, oracleAddress: asset.oracleAddr, quoteAssetAddress: asset.assetAddr, baseAssetIsNumeraire: true}));
    }

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset: "maUSD", baseAsset: "USD", oracleAddress: address(oracleStableUsdToUsd), quoteAssetAddress: address(stableUsd), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(Constants.oracleStableEthToEthUnit), baseAssetNumeraire: 1, quoteAsset: "maETH", baseAsset: "ETH", oracleAddress: address(oracleStableEthToEth), quoteAssetAddress: address(stableEth), baseAssetIsNumeraire: true}));
    vm.stopBroadcast();

  }

  function setAssetInformation() public {
    vm.startBroadcast();

    assetInfo memory asset;
    uint256[] memory creditRatings = new uint256[](2);
    address[] memory genOracleArr1 = new address[](1);
    address[] memory genOracleArr2 = new address[](2);
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      creditRatings[0] = asset.creditRatingUsd;
      creditRatings[1] = asset.creditRatingEth;
      if (StringHelpers.compareStrings(asset.baseAsset, "ETH")) {
        genOracleArr2[0] = asset.oracleAddr;
        genOracleArr2[1] = address(oracleEthToUsd);

        if (asset.decimals == 0) {
          floorERC721Registry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: genOracleArr2, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), creditRatings);
        }
        else {
          standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr2, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), creditRatings);
          }
      }
      else {
        genOracleArr1[0] = asset.oracleAddr;

        if (asset.decimals == 0) {
          floorERC721Registry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: genOracleArr1, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), creditRatings);
        }
        else {
          standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr1, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), creditRatings);
          }
      }

    }

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    address[] memory oracleStableUsdToUsdArr = new address[](1);    
    oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);

    address[] memory oracleStableEthToUsdArr = new address[](2);
    oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
    oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

    creditRatings[0] = 2;
    creditRatings[1] = 1;
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(weth)}), creditRatings);
    creditRatings[0] = 0;
    creditRatings[1] = 0;    
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableUsdToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stableUsd)}), creditRatings);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableEthToUsdArr, assetUnit: uint64(10**Constants.stableEthDecimals), assetAddress: address(stableEth)}), creditRatings);
    vm.stopBroadcast();

  }

  function storeAssets() internal {
    assets.push(assetInfo({desc: "Mocked Wrapped Ether", symbol: "mwETH", creditRatingUsd: 2, creditRatingEth: 1, decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ETH", baseAsset: "USD", oracleAddr: address(oracleEthToUsd), assetAddr: address(weth)}));
    assets.push(assetInfo({desc: "Mocked Wrapped BTC", symbol: "mwBTC", decimals: 8, creditRatingUsd: 3, creditRatingEth: 4, rate: 2934300000000, oracleDecimals: 8, quoteAsset: "BTC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked USD Coin", symbol: "mUSDC", decimals: 6, creditRatingUsd: 1, creditRatingEth: 2, rate: 100000000, oracleDecimals: 8, quoteAsset: "USDC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked SHIBA INU", symbol: "mSHIB", decimals: 18, creditRatingUsd: 9, creditRatingEth: 9, rate: 1179, oracleDecimals: 8, quoteAsset: "SHIB", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Matic Token", symbol: "mMATIC", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 6460430, oracleDecimals: 8, quoteAsset: "MATIC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Cronos Coin", symbol: "mCRO", decimals: 8, creditRatingUsd: 6, creditRatingEth: 7, rate: 1872500, oracleDecimals: 8, quoteAsset: "CRO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Uniswap", symbol: "mUNI", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 567000000, oracleDecimals: 8, quoteAsset: "UNI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked ChainLink Token", symbol: "mLINK", decimals: 18, creditRatingUsd: 3, creditRatingEth: 4, rate: 706000000, oracleDecimals: 8, quoteAsset: "LINK", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked FTX Token", symbol: "mFTT", decimals: 18, creditRatingUsd: 5, creditRatingEth: 6, rate: 2976000000, oracleDecimals: 8, quoteAsset: "FTT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked ApeCoin", symbol: "mAPE", decimals: 18, creditRatingUsd: 8, creditRatingEth: 9, rate: 765000000, oracleDecimals: 8, quoteAsset: "APE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked The Sandbox", symbol: "mSAND", decimals: 8, creditRatingUsd: 6, creditRatingEth: 7, rate: 130000000, oracleDecimals: 8, quoteAsset: "SAND", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Decentraland", symbol: "mMANA", decimals: 18, creditRatingUsd: 7, creditRatingEth: 7, rate: 103000000, oracleDecimals: 8, quoteAsset: "MANA", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Axie Infinity", symbol: "mAXS", decimals: 18, creditRatingUsd: 9, creditRatingEth: 9, rate: 2107000000, oracleDecimals: 8, quoteAsset: "AXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Aave", symbol: "mAAVE", decimals: 18, creditRatingUsd: 6, creditRatingEth: 6, rate: 9992000000, oracleDecimals: 8, quoteAsset: "AAVE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Fantom", symbol: "mFTM", decimals: 18, creditRatingUsd: 5, creditRatingEth: 6, rate: 4447550, oracleDecimals: 8, quoteAsset: "FTM", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked KuCoin Token ", symbol: "mKCS", decimals: 6, creditRatingUsd: 6, creditRatingEth: 6, rate: 1676000000, oracleDecimals: 8, quoteAsset: "KCS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Maker", symbol: "mMKR", decimals: 18, creditRatingUsd: 5, creditRatingEth: 6, rate: 131568000000, oracleDecimals: 8, quoteAsset: "MKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Dai", symbol: "mDAI", decimals: 18, creditRatingUsd: 3, creditRatingEth: 4, rate: 100000000, oracleDecimals: 8, quoteAsset: "DAI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Convex Finance", symbol: "mCVX", decimals: 18, creditRatingUsd: 7, creditRatingEth: 8, rate: 1028000000, oracleDecimals: 8, quoteAsset: "CVX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Curve DAO Token", symbol: "mCRV", decimals: 18, creditRatingUsd: 5, creditRatingEth: 6, rate: 128000000, oracleDecimals: 8, quoteAsset: "CRV", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Loopring", symbol: "mLRC", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 5711080, oracleDecimals: 8, quoteAsset: "LRC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BAT", symbol: "mBAT", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 3913420, oracleDecimals: 8, quoteAsset: "BAT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Amp", symbol: "mAMP", decimals: 18, creditRatingUsd: 7, creditRatingEth: 7, rate: 13226, oracleDecimals: 8, quoteAsset: "AMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Compound", symbol: "mCOMP", decimals: 18, creditRatingUsd: 3, creditRatingEth: 4, rate: 6943000000, oracleDecimals: 8, quoteAsset: "COMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked 1INCH Token", symbol: "m1INCH", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 9926070, oracleDecimals: 8, quoteAsset: "1INCH", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Gnosis", symbol: "mGNO", decimals: 18, creditRatingUsd: 3, creditRatingEth: 3, rate: 21117000000, oracleDecimals: 8, quoteAsset: "GNO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked OMG Network", symbol: "mOMG", decimals: 18, creditRatingUsd: 6, creditRatingEth: 6, rate: 257000000, oracleDecimals: 8, quoteAsset: "OMG", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Bancor", symbol: "mBNT", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 138000000, oracleDecimals: 8, quoteAsset: "BNT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Celsius Network", symbol: "mCEL", decimals: 4, creditRatingUsd: 0, creditRatingEth: 0, rate: 7629100, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Ankr Network", symbol: "mANKR", decimals: 18, creditRatingUsd: 7, creditRatingEth: 8, rate: 392627, oracleDecimals: 8, quoteAsset: "ANKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Frax Share ", symbol: "mFXS", decimals: 18, creditRatingUsd: 8, creditRatingEth: 8, rate: 721000000, oracleDecimals: 8, quoteAsset: "FXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Immutable X", symbol: "mIMX", decimals: 18, creditRatingUsd: 4, creditRatingEth: 5, rate: 9487620, oracleDecimals: 8, quoteAsset: "IMX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Ethereum Name Service ", symbol: "mENS", decimals: 18, creditRatingUsd: 6, creditRatingEth: 6, rate: 1238000000, oracleDecimals: 8, quoteAsset: "ENS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked SushiToken", symbol: "mSUSHI", decimals: 18, creditRatingUsd: 6, creditRatingEth: 6, rate: 166000000, oracleDecimals: 8, quoteAsset: "SUSHI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Mocked dYdX", symbol: "mDYDX", decimals: 18, creditRatingUsd: 5, creditRatingEth: 6, rate: 206000000, oracleDecimals: 8, quoteAsset: "DYDX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CelerToken", symbol: "mCELR", decimals: 18, creditRatingUsd: 8, creditRatingEth: 7, rate: 186335, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(assetInfo({desc: "Mocked CRYPTOPUNKS", symbol: "mC", decimals: 0, creditRatingUsd: 5, creditRatingEth: 4, rate: 48950000000000000000, oracleDecimals: 18, quoteAsset: "PUNK", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BoredApeYachtClub", symbol: "mBAYC", decimals: 0, creditRatingUsd: 5, creditRatingEth: 4, rate: 93990000000000000000, oracleDecimals: 18, quoteAsset: "BAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked MutantApeYachtClub", symbol: "mMAYC", decimals: 0, creditRatingUsd: 6, creditRatingEth: 5, rate: 18850000000000000000, oracleDecimals: 18, quoteAsset: "MAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CloneX", symbol: "mCloneX", decimals: 0, creditRatingUsd: 9, creditRatingEth: 8, rate: 14400000000000000000, oracleDecimals: 18, quoteAsset: "CloneX", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Loot", symbol: "mLOOT", decimals: 0, creditRatingUsd: 7, creditRatingEth: 6, rate: 1100000000000000000, oracleDecimals: 18, quoteAsset: "LOOT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Sandbox's LANDs", symbol: "mLAND", decimals: 0, creditRatingUsd: 5, creditRatingEth: 5, rate: 1630000000000000000, oracleDecimals: 18, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Cool Cats", symbol: "mCOOL", decimals: 0, creditRatingUsd: 7, creditRatingEth: 6, rate: 3490000000000000000, oracleDecimals: 18, quoteAsset: "COOL", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Azuki", symbol: "mAZUKI", decimals: 0, creditRatingUsd: 6, creditRatingEth: 6, rate: 12700000000000000000, oracleDecimals: 18, quoteAsset: "AZUKI", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Doodles", symbol: "mDOODLE", decimals: 0, creditRatingUsd: 7, creditRatingEth: 6, rate: 12690000000000000000, oracleDecimals: 18, quoteAsset: "DOODLE", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Meebits", symbol: "mMEEBIT", decimals: 0, creditRatingUsd: 8, creditRatingEth: 7, rate: 4600000000000000000, oracleDecimals: 18, quoteAsset: "MEEBIT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CyberKongz", symbol: "mKONGZ", decimals: 0, creditRatingUsd: 9, creditRatingEth: 9, rate: 2760000000000000000, oracleDecimals: 18, quoteAsset: "KONGZ", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BoredApeKennelClub", symbol: "mBAKC", decimals: 0, creditRatingUsd: 7, creditRatingEth: 6, rate: 7200000000000000000, oracleDecimals: 18, quoteAsset: "BAKC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Decentraland LAND", symbol: "mLAND", decimals: 0, creditRatingUsd: 5, creditRatingEth: 5, rate: 2000000000000000000, oracleDecimals: 18, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Timeless", symbol: "mTMLS", decimals: 0, creditRatingUsd: 8, creditRatingEth: 7, rate: 380000000000000000, oracleDecimals: 18, quoteAsset: "TMLS", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Treeverse", symbol: "mTRV", decimals: 0, creditRatingUsd: 7, creditRatingEth: 6, rate: 10500000000000000000, oracleDecimals: 18, quoteAsset: "TRV", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
  
  }

  function transferOwnership() public {
    factory.transferOwnership(msg.sender);
    oracleHub.transferOwnership(msg.sender);
    mainRegistry.transferOwnership(msg.sender);
    standardERC20Registry.transferOwnership(msg.sender);
    floorERC721Registry.transferOwnership(msg.sender);
    interestRateModule.transferOwnership(msg.sender);
    oracleStableUsdToUsd.transferOwnership(msg.sender);
    oracleStableEthToEth.transferOwnership(msg.sender);
    liquidator.transferOwnership(msg.sender);
    tokenShop.transferOwnership(msg.sender);
    oracleEthToUsd.transferOwnership(msg.sender);
  }

  function verifyView() public view returns (bool) {

    require(checkAddressesInit(), "Verification: addresses not inited");
    require(checkFactory(), "Verification: factory not set");
    require(checkStables(), "Verification: Stables not set");
    require(checkTokenShop(), "Verification: tokenShop not set");
    require(checkLiquidator(), "Verification: Liquidator not set");
    require(checkSubregs(), "Verification: Subregs not set");

    return true;
  }

  function checkMainreg() public view returns (bool) {
    require(mainRegistry.isSubRegistry(address(standardERC20Registry)), "MR: ERC20SR not set");
    require(mainRegistry.isSubRegistry(address(floorERC721Registry)), "MR: ERC721SR not set");
    require(mainRegistry.factoryAddress() == address(factory), "MR: fact not set");

    uint64 numeraireToUsdOracleUnit;
    uint64 numeraireUnit;
    address assetAddress;
    address numeraireToUsdOracle;
    address stableAddress;
    string memory numeraireLabel;

    uint256 numCounter = mainRegistry.numeraireCounter();
    require(numCounter > 0);
    for (uint i; i < numCounter; ++i) {
      (numeraireToUsdOracleUnit, numeraireUnit, assetAddress, numeraireToUsdOracle, stableAddress, numeraireLabel) = mainRegistry.numeraireToInformation(0);
      require(numeraireToUsdOracleUnit != 0 && 
              numeraireUnit != 0 && 
              assetAddress != address(0) && 
              numeraireToUsdOracle != address(0) && 
              stableAddress != address(0) && 
              bytes(numeraireLabel).length != 0, "MR: num 0 not set");
    }

    return true;
  }

  function checkSubregs() public view returns (bool) {
    require(standardERC20Registry.mainRegistry() == address(mainRegistry), "ERC20SR: mainreg not set");
    require(floorERC721Registry.mainRegistry() == address(mainRegistry), "ERC721SR: mainreg not set");
    require(standardERC20Registry.oracleHub() == address(oracleHub), "ERC20SR: OH not set");
    require(floorERC721Registry.oracleHub() == address(oracleHub), "ERC721SR: OH not set");

    return true;
  }

  function checkLiquidator() public view returns (bool) {
    require(liquidator.registryAddress() == address(mainRegistry), "Liq: mainreg not set");
    require(liquidator.factoryAddress() == address(factory), "Liq: fact not set");

    return true;
  }

  function checkTokenShop() public view returns (bool) {
    require(tokenShop.mainRegistry() == address(mainRegistry), "TokenShop: mainreg not set");

    return true;
  }

  function checkStables() public view returns (bool) {
    require(stableUsd.liquidator() == address(liquidator), "StableUSD: liq not set");
    require(stableUsd.factory() == address(factory), "StableUSD: fact not set");
    require(stableEth.liquidator() == address(liquidator), "StableETH: liq not set");
    require(stableEth.factory() == address(factory), "StableETH: fact not set");
    require(stableUsd.tokenShop() == address(tokenShop), "StableUSD: tokensh not set");
    require(stableEth.tokenShop() == address(tokenShop), "StableETH: tokensh not set");

    return true;
  }

  function checkFactory() public view returns (bool) {
    require(bytes(factory.baseURI()).length != 0, "FTRY: baseURI not set");
    uint256 numCountFact = factory.numeraireCounter();
    require(numCountFact == mainRegistry.numeraireCounter(), "FTRY: numCountFact != numCountMR");
    require(factory.liquidatorAddress() != address(0), "FTRY: LiqAddr not set");
    require(factory.newVaultInfoSet() == false, "FTRY: newVaultInfo still set");
    require(factory.getCurrentRegistry() == address(mainRegistry), "FTRY: mainreg not set");
    (, address factLogic, address factStake, address factIRM) = factory.vaultDetails(factory.currentVaultVersion());
    require(factLogic == address(vault), "FTRY: vaultLogic not set");
    require(factStake == address(stakeContract), "FTRY: stakeContr not set");
    require(factIRM == address(interestRateModule), "FTRY: IRM not set");
    for (uint256 i; i < numCountFact; ++i) {
      require(factory.numeraireToStable(i) != address(0), string(abi.encodePacked("FTRY: numToStable not set for", Strings.toString(i))));
    }

    return true;
  }

  error AddressNotInitialised();
  function checkAddressesInit() public view returns (bool) {
    require(address(factory) != address(0), "AddrCheck: factory not set");
    require(address(vault) != address(0), "AddrCheck: vault not set");
    require(address(oracleHub) != address(0), "AddrCheck: oracleHub not set");
    require(address(mainRegistry) != address(0), "AddrCheck: mainRegistry not set");
    require(address(standardERC20Registry) != address(0), "AddrCheck: standardERC20Registry not set");
    require(address(floorERC721Registry) != address(0), "AddrCheck: floorERC721Registry not set");
    require(address(interestRateModule) != address(0), "AddrCheck: interestRateModule not set");
    require(address(stableUsd) != address(0), "AddrCheck: stableUsd not set");
    require(address(stableEth) != address(0), "AddrCheck: stableEth not set");
    require(address(oracleStableUsdToUsd) != address(0), "AddrCheck: oracleStableUsdToUsd not set");
    require(address(oracleStableEthToEth) != address(0), "AddrCheck: oracleStableEthToEth not set");
    require(address(liquidator) != address(0), "AddrCheck: liquidator not set");
    require(address(tokenShop) != address(0), "AddrCheck: tokenShop not set");
    require(address(weth) != address(0), "AddrCheck: weth not set");
    require(address(oracleEthToUsd) != address(0), "AddrCheck: oracleEthToUsd not set");

    return true;
  }

  struct returnAddrs {
    address factory;
    address mainRegistry;
    address erc20subreg;
    address erc721subreg;
    address oracleHub;
    address vaultlogic;
    address liquidator;
    address interestratemodule;
    address stableUSD;
    address stableETH;
    address weth;
    address tokenShop;
    address oracleStableUsdToUsd;
    address oracleStableEthToEth;
    address oracleEthToUsd;
    assetInfo[] assets;
  }

  function returnAllAddresses() public view returns (returnAddrs memory addrs) {
    addrs.factory = address(factory);
    addrs.mainRegistry = address(mainRegistry);
    addrs.erc20subreg = address(standardERC20Registry);
    addrs.erc721subreg = address(floorERC721Registry);
    addrs.oracleHub = address(oracleHub);
    addrs.vaultlogic = address(vault);
    addrs.liquidator = address(liquidator);
    addrs.interestratemodule = address(interestRateModule);
    addrs.stableUSD = address(stableUsd);
    addrs.stableETH = address(stableEth);
    addrs.weth = address(weth);
    addrs.tokenShop = address(tokenShop);
    addrs.oracleStableUsdToUsd = address(oracleStableUsdToUsd);
    addrs.oracleStableEthToEth = address(oracleStableEthToEth);
    addrs.oracleEthToUsd = address(oracleEthToUsd);
    addrs.assets = assets;
  }

  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

}