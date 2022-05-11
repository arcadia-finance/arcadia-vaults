// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;


import "./FactoryPaperTrading.sol";
import "../Proxy.sol";
import "./VaultPaperTrading.sol";
import "./StablePaperTrading.sol";
import "../AssetRegistry/MainRegistry.sol";
import "./ERC20PaperTrading.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "./ERC721PaperTrading.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "./Oracles/StableOracle.sol";
import "../mockups/SimplifiedChainlinkOracle.sol";
import "./TokenShop.sol";
import "../utils/Strings.sol";

contract DeployContracts  {

  FactoryPaperTrading public factory;
  VaultPaperTrading public vault;
  VaultPaperTrading public proxy;
  address public proxyAddr;
  
  OracleHub public oracleHub;
  MainRegistry public mainRegistry;
  StandardERC20Registry public standardERC20Registry;
  FloorERC721SubRegistry public floorERC721Registry;
  InterestRateModule public interestRateModule;
  StablePaperTrading public stableUsd;
  StablePaperTrading public stableEth;
  StableOracle public oracleStableUsdToUsd;
  StableOracle public oracleStableEthToEth;
  Liquidator public liquidator;
  TokenShop public tokenShop;

  ERC20PaperTrading public weth;

  SimplifiedChainlinkOracle public oracleEthToUsd;

  address private creatorAddress = address(1);
  address private tokenCreatorAddress = address(2);
  address private oracleOwner = address(3);
  address private unprivilegedAddress = address(4);
  address private stakeContract = address(5);
  address private vaultOwner = address(6);

  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleStableToUsdArr = new address[](1);

  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;
    factory = new FactoryPaperTrading();
    factory.setBaseURI("ipfs://");

    stableUsd = new StablePaperTrading("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    stableEth = new StablePaperTrading("Arcadia ETH Stable Mock", "masETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory));

    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableUsdToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "masUSD / USD");
    oracleStableEthToEth = new StableOracle(uint8(Constants.oracleStableEthToEthUnit), "masEth / Eth");

    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));

    liquidator = new Liquidator(address(factory), address(mainRegistry), address(stableUsd));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    tokenShop = new TokenShop(address(mainRegistry));
    weth = new ERC20PaperTrading("ETH Mock", "mETH", uint8(Constants.ethDecimals), address(tokenShop));

    oracleHub = new OracleHub();

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(floorERC721Registry));


    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableToUsdArr[0] = address(oracleStableUsdToUsd);

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 ** 16);

    vault = new VaultPaperTrading();
    factory.setNewVaultInfo(address(mainRegistry), address(vault), stakeContract, address(interestRateModule));
    factory.confirmNewVaultInfo();
    factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));


  }

  function createVault() public onlyOwner {
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))), 0);
    proxy = VaultPaperTrading(proxyAddr);
  }

  struct assetInfo {
    string desc;
    string symbol;
    uint8 decimals;
    uint8 oracleDecimals;
    uint128 rate;
    string quoteAsset;
    address oracleAddr;
    address assetAddr;
  }

  assetInfo[] public assets;
  function storeStructs() public onlyOwner {
    assets.push(assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), rate: uint128(rateEthToUsd), oracleDecimals: uint8(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", oracleAddr: address(oracleEthToUsd), assetAddr: address(weth)}));
    
    assets.push(assetInfo({desc: "Wrapped BTC - Mock", symbol: "mwBTC", decimals: 8, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BTC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "USD Coin - Mock", symbol: "mUSDC", decimals: 6, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "USDC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SHIBA INU - Mock", symbol: "mSHIB", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SHIB", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Matic Token - Mock", symbol: "mMATIC", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MATIC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cronos Coin - Mock", symbol: "mCRO", decimals: 8, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRO", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Uniswap - Mock", symbol: "mUNI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "UNI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ChainLink Token - Mock", symbol: "mLINK", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LINK", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "FTX Token - Mock", symbol: "mFTT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ApeCoin - Mock", symbol: "mAPE", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "APE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "The Sandbox - Mock", symbol: "mSAND", decimals: 8, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland - Mock", symbol: "mMANA", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MANA", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Axie Infinity - Mock", symbol: "mAXS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AXS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Aave - Mock", symbol: "mAAVE", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AAVE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Fantom - Mock", symbol: "mFTM", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTM", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "KuCoin Token  - Mock", symbol: "mKCS", decimals: 6, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KCS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Maker - Mock", symbol: "mMKR", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MKR", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Dai - Mock", symbol: "mDAI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DAI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Convex Finance - Mock", symbol: "mCVX", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CVX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Curve DAO Token - Mock", symbol: "mCRV", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRV", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loopring - Mock", symbol: "mLRC", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LRC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BAT - Mock", symbol: "mBAT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Amp - Mock", symbol: "mAMP", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AMP", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Compound - Mock", symbol: "mCOMP", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COMP", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "1INCH Token - Mock", symbol: "m1INCH", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "1INCH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Gnosis - Mock", symbol: "mGNO", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "GNO", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "OMG Network - Mock", symbol: "mOMG", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "OMG", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Bancor - Mock", symbol: "mBNT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BNT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Celsius Network - Mock", symbol: "mCEL", decimals: 4, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ankr Network - Mock", symbol: "mANKR", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ANKR", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Frax Share  - Mock", symbol: "mFXS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FXS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Immutable X - Mock", symbol: "mIMX", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "IMX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ethereum Name Service  - Mock", symbol: "mENS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ENS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SushiToken - Mock", symbol: "mSUSHI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SUSHI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "dYdX - Mock", symbol: "mDYDX", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DYDX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CelerToken - Mock", symbol: "mCELR", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(assetInfo({desc: "CRYPTOPUNKS - Mock", symbol: "mC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "PUNK", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeYachtClub - Mock", symbol: "mBAYC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAYC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "MutantApeYachtClub - Mock", symbol: "mMAYC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MAYC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CloneX - Mock", symbol: "mCloneX", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CloneX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loot - Mock", symbol: "mLOOT", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LOOT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Sandbox's LANDs - Mock", symbol: "mLAND", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cool Cats - Mock", symbol: "mCOOL", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COOL", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Azuki - Mock", symbol: "mAZUKI", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AZUKI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Doodles - Mock", symbol: "mDOODLE", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DOODLE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Meebits - Mock", symbol: "mMEEBIT", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MEEBIT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CyberKongz - Mock", symbol: "mKONGZ", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KONGZ", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeKennelClub - Mock", symbol: "mBAKC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAKC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland LAND - Mock", symbol: "mLAND", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Timeless - Mock", symbol: "mTMLS", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TMLS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Treeverse - Mock", symbol: "mTRV", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TRV", oracleAddr: address(0), assetAddr: address(0)}));
  }

  function deployERC20Contracts() public onlyOwner {
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
  }

  function deployERC721Contracts() public onlyOwner {
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
  }

  function deployOracles() public onlyOwner {
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      newContr = address(new SimplifiedChainlinkOracle(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD"))));
      assets[i].oracleAddr = newContr;
    }

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

  }

  function setOracleAnswers() public onlyOwner {
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      SimplifiedChainlinkOracle(asset.oracleAddr).setAnswer(int256(uint256(asset.rate)));
    }
  }

  function addOracles() public onlyOwner {
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(10**asset.oracleDecimals), baseAssetNumeraire: 0, quoteAsset: asset.quoteAsset, baseAsset: "USD", oracleAddress: asset.oracleAddr, quoteAssetAddress: asset.assetAddr, baseAssetIsNumeraire: true}));
    }

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(10**18), baseAssetNumeraire: 0, quoteAsset: "STABLE", baseAsset: "USD", oracleAddress: address(oracleStableUsdToUsd), quoteAssetAddress: address(0), baseAssetIsNumeraire: true}));

  }

  function setAssetInformation() public onlyOwner {
    assetInfo memory asset;
    uint256[] memory emptyList = new uint256[](0);
    address[] memory genOracleArr = new address[](1);
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      genOracleArr[0] = asset.oracleAddr;
      if (asset.decimals == 0) {
        floorERC721Registry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: genOracleArr, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), emptyList);
      }
      else {
        standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), emptyList);
        }
    }

  }

  function transferOwnerships() public onlyOwner {
    factory.transfer;
    vault;
    proxy;
    
    oracleHub;
    mainRegistry;
    standardERC20Registry;
    floorERC721Registry;
    interestRateModule;
    stableUsd;
    stableEth;
    oracleStableUsdToUsd;
    oracleStableEthToEth;
    liquidator;
    tokenShop;

    weth;

    oracleEthToUsd;
  }

  function returnAssets() public view returns (assetInfo[] memory) {
    return assets;
  }

  function verify() public onlyOwner returns (bool) {
    storeStructs();
    deployERC20Contracts();
    deployERC721Contracts();
    deployOracles();
    setOracleAnswers();
    addOracles();
    setAssetInformation();

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
    require(standardERC20Registry._mainRegistry() == address(mainRegistry), "ERC20SR: mainreg not set");
    require(floorERC721Registry._mainRegistry() == address(mainRegistry), "ERC721SR: mainreg not set");
    require(standardERC20Registry._oracleHub() == address(oracleHub), "ERC20SR: OH not set");
    require(floorERC721Registry._oracleHub() == address(oracleHub), "ERC721SR: OH not set");

    return true;
  }

  function checkLiquidator() public view returns (bool) {
    require(liquidator.registryAddress() == address(mainRegistry), "Liq: mainreg not set");
    require(liquidator.factoryAddress() == address(factory), "Liq: fact not set");
    require(liquidator.stable() == address(stableUsd), "Liq: stable not set");

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
    require(owner != address(0), "AddrCheck: owner not set");
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

}
