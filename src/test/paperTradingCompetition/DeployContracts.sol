// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;


import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../Proxy.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../paperTradingCompetition/ERC721PaperTrading.sol";
import "../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";
import "../../paperTradingCompetition/Oracles/StableOracle.sol";
import "../../mockups/SimplifiedChainlinkOracle.sol";
import "../../paperTradingCompetition/TokenShop.sol";

contract DeployContracts  {

  FactoryPaperTrading public factory;
  VaultPaperTrading public vault;
  VaultPaperTrading public proxy;
  address public proxyAddr;
  
  OracleHub public oracleHub;
  StableOracle public oracleStableToUsd;
  MainRegistry public mainRegistry;
  StandardERC20Registry public standardERC20Registry;
  FloorERC721SubRegistry public floorERC721Registry;
  InterestRateModule public interestRateModule;
  StablePaperTrading public stable;
  StableOracle public oracle;
  Liquidator public liquidator;
  TokenShop public tokenShop;

  ERC20PaperTrading public weth;
  ERC20PaperTrading public wbtc;
  ERC20PaperTrading public usdc;
  ERC20PaperTrading public shib;
  ERC20PaperTrading public matic;
  ERC20PaperTrading public cro;
  ERC20PaperTrading public uni;
  ERC20PaperTrading public link;
  ERC20PaperTrading public ftt;
  ERC20PaperTrading public ape;
  ERC20PaperTrading public sandbox;
  ERC20PaperTrading public mana;
  ERC20PaperTrading public axs;
  ERC20PaperTrading public aave;
  ERC20PaperTrading public ftm;
  ERC20PaperTrading public kcs;
  ERC20PaperTrading public mkr;
  ERC20PaperTrading public dai;
  ERC20PaperTrading public cvx;
  ERC20PaperTrading public crv;
  ERC20PaperTrading public lrc;
  ERC20PaperTrading public bat;
  ERC20PaperTrading public amp;
  ERC20PaperTrading public comp;
  ERC20PaperTrading public oneinch;
  ERC20PaperTrading public gno;
  ERC20PaperTrading public omg;
  ERC20PaperTrading public bnt;
  ERC20PaperTrading public cel;
  ERC20PaperTrading public ankr;
  ERC20PaperTrading public fxs;
  ERC20PaperTrading public imx;
  ERC20PaperTrading public ens;
  ERC20PaperTrading public sushi;
  ERC20PaperTrading public dydx;
  ERC20PaperTrading public celr;


  ERC721PaperTrading public cryptopunks;
  ERC721PaperTrading public bayc;
  ERC721PaperTrading public mayc;
  ERC721PaperTrading public clonex;
  ERC721PaperTrading public loot;
  ERC721PaperTrading public sandboxnft;
  ERC721PaperTrading public coolcats;
  ERC721PaperTrading public azuki;
  ERC721PaperTrading public doodles;
  ERC721PaperTrading public meebits;
  ERC721PaperTrading public cyberkongz;
  ERC721PaperTrading public bakc;
  ERC721PaperTrading public decentraland;
  ERC721PaperTrading public timeless;
  ERC721PaperTrading public foundersplot;
  ERC721PaperTrading public mfer;
  ERC721PaperTrading public moonbirds;

  SimplifiedChainlinkOracle public oracleEthToUsd;
  SimplifiedChainlinkOracle public oracleBtcToUsd;
  SimplifiedChainlinkOracle public oracleUsdcToUsd;
  SimplifiedChainlinkOracle public oracleShibToUsd;
  SimplifiedChainlinkOracle public oracleMaticToUsd;
  SimplifiedChainlinkOracle public oracleCroToUsd;
  SimplifiedChainlinkOracle public oracleUniToUsd;
  SimplifiedChainlinkOracle public oracleLinkToUsd;
  SimplifiedChainlinkOracle public oracleFttToUsd;
  SimplifiedChainlinkOracle public oracleApeToUsd;
  SimplifiedChainlinkOracle public oracleSandboxToUsd;
  SimplifiedChainlinkOracle public oracleManaToUsd;
  SimplifiedChainlinkOracle public oracleAxsToUsd;
  SimplifiedChainlinkOracle public oracleAaveToUsd;
  SimplifiedChainlinkOracle public oracleFtmToUsd;
  SimplifiedChainlinkOracle public oracleKcsToUsd;
  SimplifiedChainlinkOracle public oracleMkrToUsd;
  SimplifiedChainlinkOracle public oracleDaiToUsd;
  SimplifiedChainlinkOracle public oracleCvxToUsd;
  SimplifiedChainlinkOracle public oracleCrvToUsd;
  SimplifiedChainlinkOracle public oracleLrcToUsd;
  SimplifiedChainlinkOracle public oracleBatToUsd;
  SimplifiedChainlinkOracle public oracleAmpToUsd;
  SimplifiedChainlinkOracle public oracleCompToUsd;
  SimplifiedChainlinkOracle public oracle1InchToUsd;
  SimplifiedChainlinkOracle public oracleGnoToUsd;
  SimplifiedChainlinkOracle public oracleOmgToUsd;
  SimplifiedChainlinkOracle public oracleBntToUsd;
  SimplifiedChainlinkOracle public oracleCelToUsd;
  SimplifiedChainlinkOracle public oracleAnkrToUsd;
  SimplifiedChainlinkOracle public oracleFxsToUsd;
  SimplifiedChainlinkOracle public oracleImxToUsd;
  SimplifiedChainlinkOracle public oracleEnsToUsd;
  SimplifiedChainlinkOracle public oracleSushiToUsd;
  SimplifiedChainlinkOracle public oracleDydxToUsd;
  SimplifiedChainlinkOracle public oracleCelrToUsd;


  SimplifiedChainlinkOracle public oraclePunkToUsd;
  SimplifiedChainlinkOracle public oracleBaycToUsd;
  SimplifiedChainlinkOracle public oracleMaycToUsd;
  SimplifiedChainlinkOracle public oracleClonexToUsd;
  SimplifiedChainlinkOracle public oracleLootToUsd;
  SimplifiedChainlinkOracle public oracleSandboxnftToUsd;
  SimplifiedChainlinkOracle public oracleCoolcatsToUsd;
  SimplifiedChainlinkOracle public oracleAzukiToUsd;
  SimplifiedChainlinkOracle public oracleDoodlesToUsd;
  SimplifiedChainlinkOracle public oracleMeebitsToUsd;
  SimplifiedChainlinkOracle public oracleCyberkongzToUsd;
  SimplifiedChainlinkOracle public oracleBakcToUsd;
  SimplifiedChainlinkOracle public oracleDecentralandToUsd;
  SimplifiedChainlinkOracle public oracleTimelessToUsd;
  SimplifiedChainlinkOracle public oracleFoundersplotToUsd;


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

  //this is a before
  constructor() {
    owner = msg.sender;

    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, numeraireLabel:'USD', numeraireUnit:1}));

    tokenShop = new TokenShop(address(mainRegistry));

    stable = new StablePaperTrading("Arcadia Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
    liquidator = new Liquidator(0x0000000000000000000000000000000000000000, address(mainRegistry), address(stable));
    stable.setLiquidator(address(liquidator));

    oracleHub = new OracleHub();

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(floorERC721Registry));


    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableToUsdArr[0] = address(oracleStableToUsd);

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 ** 16);

    vault = new VaultPaperTrading();
    factory = new FactoryPaperTrading();
    factory.setVaultInfo(1, address(mainRegistry), address(vault), address(stable), stakeContract, address(interestRateModule), address(interestRateModule));
    factory.setVaultVersion(1);
    factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));
    stable.setFactory(address(factory));

  }

  function createVault() public onlyOwner {
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))));
    proxy = VaultPaperTrading(proxyAddr);
  }


  struct assetInfo {
    string desc;
    string symbol;
    uint8 decimals;
    uint64 oracleDecimals;
    string tradePair;
    uint128 rate;
    string quoteAsset;
    address oracleAddr;
    address assetAddr;
  }

  assetInfo[] public assets;
  function storeStructs() public onlyOwner {
    assets.push(assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), tradePair: "ETH / USD", rate: uint128(rateEthToUsd), oracleDecimals: uint64(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    
    assets.push(assetInfo({desc: "Wrapped BTC - Mock", symbol: "mwBTC", decimals: 8, tradePair: "BTC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BTC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "USD Coin - Mock", symbol: "mUSDC", decimals: 6, tradePair: "USDC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "USDC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SHIBA INU - Mock", symbol: "mSHIB", decimals: 18, tradePair: "SHIB / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SHIB", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Matic Token - Mock", symbol: "mMATIC", decimals: 18, tradePair: "MATIC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MATIC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cronos Coin - Mock", symbol: "mCRO", decimals: 8, tradePair: "CRO / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRO", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Uniswap - Mock", symbol: "mUNI", decimals: 18, tradePair: "UNI / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "UNI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ChainLink Token - Mock", symbol: "mLINK", decimals: 18, tradePair: "LINK / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LINK", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "FTX Token - Mock", symbol: "mFTT", decimals: 18, tradePair: "FTT / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ApeCoin - Mock", symbol: "mAPE", decimals: 18, tradePair: "APE / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "APE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "The Sandbox - Mock", symbol: "mSAND", decimals: 8, tradePair: "SAND / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland - Mock", symbol: "mMANA", decimals: 18, tradePair: "MANA / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MANA", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Axie Infinity - Mock", symbol: "mAXS", decimals: 18, tradePair: "AXS / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AXS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Aave - Mock", symbol: "mAAVE", decimals: 18, tradePair: "AAVE / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AAVE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Fantom - Mock", symbol: "mFTM", decimals: 18, tradePair: "FTM / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTM", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "KuCoin Token  - Mock", symbol: "mKCS", decimals: 6, tradePair: "KCS / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KCS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Maker - Mock", symbol: "mMKR", decimals: 18, tradePair: "MKR / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MKR", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Dai - Mock", symbol: "mDAI", decimals: 18, tradePair: "DAI / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DAI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Convex Finance - Mock", symbol: "mCVX", decimals: 18, tradePair: "CVX / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CVX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Curve DAO Token - Mock", symbol: "mCRV", decimals: 18, tradePair: "CRV / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRV", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loopring - Mock", symbol: "mLRC", decimals: 18, tradePair: "LRC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LRC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BAT - Mock", symbol: "mBAT", decimals: 18, tradePair: "BAT / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Amp - Mock", symbol: "mAMP", decimals: 18, tradePair: "AMP / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AMP", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Compound - Mock", symbol: "mCOMP", decimals: 18, tradePair: "COMP / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COMP", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "1INCH Token - Mock", symbol: "m1INCH", decimals: 18, tradePair: "1INCH / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "1INCH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Gnosis - Mock", symbol: "mGNO", decimals: 18, tradePair: "GNO / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "GNO", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "OMG Network - Mock", symbol: "mOMG", decimals: 18, tradePair: "OMG / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "OMG", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Bancor - Mock", symbol: "mBNT", decimals: 18, tradePair: "BNT / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BNT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Celsius Network - Mock", symbol: "mCEL", decimals: 4, tradePair: "CEL / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ankr Network - Mock", symbol: "mANKR", decimals: 18, tradePair: "ANKR / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ANKR", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Frax Share  - Mock", symbol: "mFXS", decimals: 18, tradePair: "FXS / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FXS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Immutable X - Mock", symbol: "mIMX", decimals: 18, tradePair: "IMX / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "IMX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ethereum Name Service  - Mock", symbol: "mENS", decimals: 18, tradePair: "ENS / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ENS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SushiToken - Mock", symbol: "mSUSHI", decimals: 18, tradePair: "SUSHI / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SUSHI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "dYdX - Mock", symbol: "mDYDX", decimals: 18, tradePair: "DYDX / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DYDX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CelerToken - Mock", symbol: "mCELR", decimals: 18, tradePair: "CEL / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(assetInfo({desc: "CRYPTOPUNKS - Mock", symbol: "mC", decimals: 0, tradePair: "PUNK / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "PUNK", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeYachtClub - Mock", symbol: "mBAYC", decimals: 0, tradePair: "BAYC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAYC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "MutantApeYachtClub - Mock", symbol: "mMAYC", decimals: 0, tradePair: "MAYC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MAYC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CloneX - Mock", symbol: "mCloneX", decimals: 0, tradePair: "CloneX / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CloneX", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loot - Mock", symbol: "mLOOT", decimals: 0, tradePair: "LOOT / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LOOT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Sandbox's LANDs - Mock", symbol: "mLAND", decimals: 0, tradePair: "LAND / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cool Cats - Mock", symbol: "mCOOL", decimals: 0, tradePair: "COOL / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COOL", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Azuki - Mock", symbol: "mAZUKI", decimals: 0, tradePair: "AZUKI / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AZUKI", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Doodles - Mock", symbol: "mDOODLE", decimals: 0, tradePair: "DOODLE / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DOODLE", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Meebits - Mock", symbol: "mMEEBIT", decimals: 0, tradePair: "MEEBIT / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MEEBIT", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CyberKongz - Mock", symbol: "mKONGZ", decimals: 0, tradePair: "KONGZ / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KONGZ", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeKennelClub - Mock", symbol: "mBAKC", decimals: 0, tradePair: "BAKC / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAKC", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland LAND - Mock", symbol: "mLAND", decimals: 0, tradePair: "LAND / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Timeless - Mock", symbol: "mTMLS", decimals: 0, tradePair: "TMLS / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TMLS", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Treeverse - Mock", symbol: "mTRV", decimals: 0, tradePair: "TRV / USD", rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TRV", oracleAddr: address(0), assetAddr: address(0)}));
  }

  function deployAssetContracts() public onlyOwner {
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (asset.decimals == 0) {
        newContr = address(new ERC721PaperTrading(asset.desc, asset.symbol, address(tokenShop)));
      }
      else {
        newContr = address(new ERC20PaperTrading(asset.desc, asset.symbol, asset.decimals, address(tokenShop)));
      }
      assets[i].assetAddr = newContr;
    }
  }

  function deployAssets() public onlyOwner {
    weth = new ERC20PaperTrading("Wrapped Ether - Mock", "mwETH", uint8(Constants.ethDecimals), address(tokenShop));
    wbtc = new ERC20PaperTrading("Wrapped BTC - Mock", "mwBTC", uint8(8), address(tokenShop));
    usdc = new ERC20PaperTrading("USD Coin - Mock", "mUSDC", uint8(6), address(tokenShop));
    shib = new ERC20PaperTrading("SHIBA INU - Mock", "mSHIB", uint8(18), address(tokenShop));
    matic = new ERC20PaperTrading("Matic Token - Mock", "mMATIC", uint8(18), address(tokenShop));
    cro = new ERC20PaperTrading("Cronos Coin - Mock", "mCRO", uint8(8), address(tokenShop));
    uni = new ERC20PaperTrading("Uniswap - Mock", "mUNI", uint8(18), address(tokenShop));
    link = new ERC20PaperTrading("ChainLink Token - Mock", "mLINK", uint8(18), address(tokenShop));
    ftt = new ERC20PaperTrading("FTX Token - Mock", "mFTT", uint8(18), address(tokenShop));
    ape = new ERC20PaperTrading("ApeCoin - Mock", "mAPE", uint8(18), address(tokenShop));
    sandbox = new ERC20PaperTrading("The Sandbox - Mock", "mSAND", uint8(8), address(tokenShop));
    mana = new ERC20PaperTrading("Decentraland - Mock", "mMANA", uint8(18), address(tokenShop));
    axs = new ERC20PaperTrading("Axie Infinity - Mock", "mAXS", uint8(18), address(tokenShop));
    aave = new ERC20PaperTrading("Aave - Mock", "mAAVE", uint8(18), address(tokenShop));
    ftm = new ERC20PaperTrading("Fantom - Mock", "mFTM", uint8(18), address(tokenShop));
    kcs = new ERC20PaperTrading("KuCoin Token - Mock", "mKCS", uint8(6), address(tokenShop));
    mkr = new ERC20PaperTrading("Maker - Mock", "mMKR", uint8(18), address(tokenShop));
    dai = new ERC20PaperTrading("Dai - Mock", "mDAI", uint8(18), address(tokenShop));
    cvx = new ERC20PaperTrading("Convex Finance - Mock", "mCVX", uint8(18), address(tokenShop));
    crv = new ERC20PaperTrading("Curve DAO Token - Mock", "mCRV", uint8(18), address(tokenShop));
    lrc = new ERC20PaperTrading("Loopring - Mock", "mLRC", uint8(18), address(tokenShop));
    bat = new ERC20PaperTrading("BAT - Mock", "mBAT", uint8(18), address(tokenShop));
    amp = new ERC20PaperTrading("Amp - Mock", "mAMP", uint8(18), address(tokenShop));
    comp = new ERC20PaperTrading("Compound - Mock", "mCOMP", uint8(18), address(tokenShop));
    oneinch = new ERC20PaperTrading("1INCH Token - Mock", "m1INCH", uint8(18), address(tokenShop));
    gno = new ERC20PaperTrading("Gnosis - Mock", "mGNO", uint8(18), address(tokenShop));
    omg = new ERC20PaperTrading("OMG Network - Mock", "mOMG", uint8(18), address(tokenShop));
    bnt = new ERC20PaperTrading("Bancor - Mock", "mBNT", uint8(18), address(tokenShop));
    cel = new ERC20PaperTrading("Celsius Network - Mock", "mCEL", uint8(4), address(tokenShop));
    ankr = new ERC20PaperTrading("Ankr Network - Mock", "mANKR", uint8(18), address(tokenShop));
    fxs = new ERC20PaperTrading("Frax Share - Mock", "mFXS", uint8(18), address(tokenShop));
    imx = new ERC20PaperTrading("Immutable X - Mock", "mIMX", uint8(18), address(tokenShop));
    ens = new ERC20PaperTrading("Ethereum Name Service - Mock", "mENS", uint8(18), address(tokenShop));
    sushi = new ERC20PaperTrading("SushiToken - Mock", "mSUSHI", uint8(18), address(tokenShop));
    dydx = new ERC20PaperTrading("dYdX - Mock", "mDYDX", uint8(18), address(tokenShop));
    celr = new ERC20PaperTrading("CelerToken - Mock", "mCELR", uint8(18), address(tokenShop));


    //
    // ERC721
    //

    cryptopunks = new ERC721PaperTrading("CRYPTOPUNKS - Mock", "mC", address(tokenShop));
    bayc = new ERC721PaperTrading("BoredApeYachtClub - Mock", "mBAYC", address(tokenShop));
    mayc = new ERC721PaperTrading("MutantApeYachtClub - Mock", "mMAYC", address(tokenShop));
    clonex = new ERC721PaperTrading("CloneX - Mock", "mCloneX", address(tokenShop));
    loot = new ERC721PaperTrading("Loot - Mock", "mLOOT", address(tokenShop));
    sandboxnft = new ERC721PaperTrading("Sandbox's LANDs - Mock", "mLAND", address(tokenShop));
    coolcats = new ERC721PaperTrading("Cool Cats - Mock", "mCOOL", address(tokenShop));
    azuki = new ERC721PaperTrading("Azuki - Mock", "mAZUKI", address(tokenShop));
    doodles = new ERC721PaperTrading("Doodles - Mock", "mDOODLE", address(tokenShop));
    meebits = new ERC721PaperTrading("Meebits - Mock", "mMEEBIT", address(tokenShop));
    cyberkongz = new ERC721PaperTrading("CyberKongz - Mock", "mKONGZ", address(tokenShop));
    bakc = new ERC721PaperTrading("BoredApeKennelClub - Mock", "mBAKC", address(tokenShop));
    decentraland = new ERC721PaperTrading("Decentraland LAND - Mock", "mLAND", address(tokenShop));
    timeless = new ERC721PaperTrading("Timeless - Mock", "mTMLS", address(tokenShop));
    foundersplot = new ERC721PaperTrading("Treeverse", "mTRV", address(tokenShop));

    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleBtcToUsd = new SimplifiedChainlinkOracle(uint8(8), "BTC / USD");
    oracleUsdcToUsd = new SimplifiedChainlinkOracle(uint8(8), "USDC / USD");
    oracleShibToUsd = new SimplifiedChainlinkOracle(uint8(8), "SHIB / USD");
    oracleMaticToUsd = new SimplifiedChainlinkOracle(uint8(8), "MATIC / USD");
    oracleCroToUsd = new SimplifiedChainlinkOracle(uint8(8), "CRO / USD");
    oracleUniToUsd = new SimplifiedChainlinkOracle(uint8(8), "UNI / USD");
    oracleLinkToUsd = new SimplifiedChainlinkOracle(uint8(8), "LINK / USD");
    oracleFttToUsd = new SimplifiedChainlinkOracle(uint8(8), "FTT / USD");
    oracleApeToUsd = new SimplifiedChainlinkOracle(uint8(8), "APE / USD");
    oracleSandboxToUsd = new SimplifiedChainlinkOracle(uint8(8), "SAND / USD");
    oracleManaToUsd = new SimplifiedChainlinkOracle(uint8(8), "MANA / USD");
    oracleAxsToUsd = new SimplifiedChainlinkOracle(uint8(8), "AXS / USD");
    oracleAaveToUsd = new SimplifiedChainlinkOracle(uint8(8), "AAVE / USD");
    oracleFtmToUsd = new SimplifiedChainlinkOracle(uint8(8), "FTM / USD");
    oracleKcsToUsd = new SimplifiedChainlinkOracle(uint8(8), "KCS / USD");
    oracleMkrToUsd = new SimplifiedChainlinkOracle(uint8(8), "MKR / USD");
    oracleDaiToUsd = new SimplifiedChainlinkOracle(uint8(8), "DAI / USD");
    oracleCvxToUsd = new SimplifiedChainlinkOracle(uint8(8), "CVX / USD");
    oracleCrvToUsd = new SimplifiedChainlinkOracle(uint8(8), "CRV / USD");
    oracleLrcToUsd = new SimplifiedChainlinkOracle(uint8(8), "LRC / USD");
    oracleBatToUsd = new SimplifiedChainlinkOracle(uint8(8), "BAT / USD");
    oracleAmpToUsd = new SimplifiedChainlinkOracle(uint8(8), "AMP / USD");
    oracleCompToUsd = new SimplifiedChainlinkOracle(uint8(8), "COMP / USD");
    oracle1InchToUsd = new SimplifiedChainlinkOracle(uint8(8), "1INCH / USD");
    oracleGnoToUsd = new SimplifiedChainlinkOracle(uint8(8), "GNO / USD");
    oracleOmgToUsd = new SimplifiedChainlinkOracle(uint8(8), "OMG / USD");
    oracleBntToUsd = new SimplifiedChainlinkOracle(uint8(8), "BNT / USD");
    oracleCelToUsd = new SimplifiedChainlinkOracle(uint8(8), "CEL / USD");
    oracleAnkrToUsd = new SimplifiedChainlinkOracle(uint8(8), "ANKR / USD");
    oracleFxsToUsd = new SimplifiedChainlinkOracle(uint8(8), "FXS / USD");
    oracleImxToUsd = new SimplifiedChainlinkOracle(uint8(8), "IMX / USD");
    oracleEnsToUsd = new SimplifiedChainlinkOracle(uint8(8), "ENS / USD");
    oracleSushiToUsd = new SimplifiedChainlinkOracle(uint8(8), "SUSHI / USD");
    oracleDydxToUsd = new SimplifiedChainlinkOracle(uint8(8), "DYDX / USD");
    oracleCelrToUsd = new SimplifiedChainlinkOracle(uint8(8), "CEL / USD");


    oraclePunkToUsd = new SimplifiedChainlinkOracle(uint8(8), "PUNK / USD");
    oracleBaycToUsd = new SimplifiedChainlinkOracle(uint8(8), "BAYC / USD");
    oracleMaycToUsd = new SimplifiedChainlinkOracle(uint8(8), "MAYC / USD");
    oracleClonexToUsd = new SimplifiedChainlinkOracle(uint8(8), "CloneX / USD");
    oracleLootToUsd = new SimplifiedChainlinkOracle(uint8(8), "LOOT / USD");
    oracleSandboxnftToUsd = new SimplifiedChainlinkOracle(uint8(8), "LAND / USD");
    oracleCoolcatsToUsd = new SimplifiedChainlinkOracle(uint8(8), "COOL / USD");
    oracleAzukiToUsd = new SimplifiedChainlinkOracle(uint8(8), "AZUKI / USD");
    oracleDoodlesToUsd = new SimplifiedChainlinkOracle(uint8(8), "DOODLE / USD");
    oracleMeebitsToUsd = new SimplifiedChainlinkOracle(uint8(8), "MEEBIT / USD");
    oracleCyberkongzToUsd = new SimplifiedChainlinkOracle(uint8(8), "KONGZ / USD");
    oracleBakcToUsd = new SimplifiedChainlinkOracle(uint8(8), "BAKC / USD");
    oracleDecentralandToUsd = new SimplifiedChainlinkOracle(uint8(8), "LAND / USD");
    oracleTimelessToUsd = new SimplifiedChainlinkOracle(uint8(8), "TMLS / USD");
    oracleFoundersplotToUsd = new SimplifiedChainlinkOracle(uint8(8), "TRV / USD");

    oracleEthToUsd.setAnswer(int256(rateEthToUsd));
    oracleBtcToUsd.setAnswer(int256(rateEthToUsd));
    oracleUsdcToUsd.setAnswer(int256(rateEthToUsd));
    oracleShibToUsd.setAnswer(int256(rateEthToUsd));
    oracleMaticToUsd.setAnswer(int256(rateEthToUsd));
    oracleCroToUsd.setAnswer(int256(rateEthToUsd));
    oracleUniToUsd.setAnswer(int256(rateEthToUsd));
    oracleLinkToUsd.setAnswer(int256(rateEthToUsd));
    oracleFttToUsd.setAnswer(int256(rateEthToUsd));
    oracleApeToUsd.setAnswer(int256(rateEthToUsd));
    oracleSandboxToUsd.setAnswer(int256(rateEthToUsd));
    oracleManaToUsd.setAnswer(int256(rateEthToUsd));
    oracleAxsToUsd.setAnswer(int256(rateEthToUsd));
    oracleAaveToUsd.setAnswer(int256(rateEthToUsd));
    oracleFtmToUsd.setAnswer(int256(rateEthToUsd));
    oracleKcsToUsd.setAnswer(int256(rateEthToUsd));
    oracleMkrToUsd.setAnswer(int256(rateEthToUsd));
    oracleDaiToUsd.setAnswer(int256(rateEthToUsd));
    oracleCvxToUsd.setAnswer(int256(rateEthToUsd));
    oracleCrvToUsd.setAnswer(int256(rateEthToUsd));
    oracleLrcToUsd.setAnswer(int256(rateEthToUsd));
    oracleBatToUsd.setAnswer(int256(rateEthToUsd));
    oracleAmpToUsd.setAnswer(int256(rateEthToUsd));
    oracleCompToUsd.setAnswer(int256(rateEthToUsd));
    oracle1InchToUsd.setAnswer(int256(rateEthToUsd));
    oracleGnoToUsd.setAnswer(int256(rateEthToUsd));
    oracleOmgToUsd.setAnswer(int256(rateEthToUsd));
    oracleBntToUsd.setAnswer(int256(rateEthToUsd));
    oracleCelToUsd.setAnswer(int256(rateEthToUsd));
    oracleAnkrToUsd.setAnswer(int256(rateEthToUsd));
    oracleFxsToUsd.setAnswer(int256(rateEthToUsd));
    oracleImxToUsd.setAnswer(int256(rateEthToUsd));
    oracleEnsToUsd.setAnswer(int256(rateEthToUsd));
    oracleSushiToUsd.setAnswer(int256(rateEthToUsd));
    oracleDydxToUsd.setAnswer(int256(rateEthToUsd));
    oracleCelrToUsd.setAnswer(int256(rateEthToUsd));

    oraclePunkToUsd.setAnswer(int256(rateEthToUsd));
    oracleBaycToUsd.setAnswer(int256(rateEthToUsd));
    oracleMaycToUsd.setAnswer(int256(rateEthToUsd));
    oracleClonexToUsd.setAnswer(int256(rateEthToUsd));
    oracleLootToUsd.setAnswer(int256(rateEthToUsd));
    oracleSandboxnftToUsd.setAnswer(int256(rateEthToUsd));
    oracleCoolcatsToUsd.setAnswer(int256(rateEthToUsd));
    oracleAzukiToUsd.setAnswer(int256(rateEthToUsd));
    oracleDoodlesToUsd.setAnswer(int256(rateEthToUsd));
    oracleMeebitsToUsd.setAnswer(int256(rateEthToUsd));
    oracleCyberkongzToUsd.setAnswer(int256(rateEthToUsd));
    oracleBakcToUsd.setAnswer(int256(rateEthToUsd));
    oracleDecentralandToUsd.setAnswer(int256(rateEthToUsd));
    oracleTimelessToUsd.setAnswer(int256(rateEthToUsd));
    oracleFoundersplotToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "STABLE / USD");

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ETH', baseAsset:'USD', oracleAddress:address(oracleEthToUsd), quoteAssetAddress:address(weth), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'STABLE', baseAsset:'USD', oracleAddress:address(oracleStableToUsd), quoteAssetAddress:address(stable), baseAssetIsNumeraire: true}));
    
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'BTC', baseAsset:'USD', oracleAddress:address(oracleBtcToUsd), quoteAssetAddress:address(wbtc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'USDC', baseAsset:'USD', oracleAddress:address(oracleUsdcToUsd), quoteAssetAddress:address(usdc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'SHIB', baseAsset:'USD', oracleAddress:address(oracleShibToUsd), quoteAssetAddress:address(shib), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'MATIC', baseAsset:'USD', oracleAddress:address(oracleMaticToUsd), quoteAssetAddress:address(matic), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CRO', baseAsset:'USD', oracleAddress:address(oracleCroToUsd), quoteAssetAddress:address(cro), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'UNI', baseAsset:'USD', oracleAddress:address(oracleUniToUsd), quoteAssetAddress:address(uni), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LINK', baseAsset:'USD', oracleAddress:address(oracleLinkToUsd), quoteAssetAddress:address(link), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'FTT', baseAsset:'USD', oracleAddress:address(oracleFttToUsd), quoteAssetAddress:address(ftt), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'APE', baseAsset:'USD', oracleAddress:address(oracleApeToUsd), quoteAssetAddress:address(ape), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'SANDBOX', baseAsset:'USD', oracleAddress:address(oracleSandboxToUsd), quoteAssetAddress:address(sandbox), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'MANA', baseAsset:'USD', oracleAddress:address(oracleManaToUsd), quoteAssetAddress:address(mana), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'AXS', baseAsset:'USD', oracleAddress:address(oracleAxsToUsd), quoteAssetAddress:address(axs), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'AAVE', baseAsset:'USD', oracleAddress:address(oracleAaveToUsd), quoteAssetAddress:address(aave), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'FTM', baseAsset:'USD', oracleAddress:address(oracleFtmToUsd), quoteAssetAddress:address(ftm), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'KCS', baseAsset:'USD', oracleAddress:address(oracleKcsToUsd), quoteAssetAddress:address(kcs), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'MKR', baseAsset:'USD', oracleAddress:address(oracleMkrToUsd), quoteAssetAddress:address(mkr), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'DAI', baseAsset:'USD', oracleAddress:address(oracleDaiToUsd), quoteAssetAddress:address(dai), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CVX', baseAsset:'USD', oracleAddress:address(oracleCvxToUsd), quoteAssetAddress:address(cvx), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CRV', baseAsset:'USD', oracleAddress:address(oracleCrvToUsd), quoteAssetAddress:address(crv), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LRC', baseAsset:'USD', oracleAddress:address(oracleLrcToUsd), quoteAssetAddress:address(lrc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'BAT', baseAsset:'USD', oracleAddress:address(oracleBatToUsd), quoteAssetAddress:address(bat), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'AMP', baseAsset:'USD', oracleAddress:address(oracleAmpToUsd), quoteAssetAddress:address(amp), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'COMP', baseAsset:'USD', oracleAddress:address(oracleCompToUsd), quoteAssetAddress:address(comp), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'1INCH', baseAsset:'USD', oracleAddress:address(oracle1InchToUsd), quoteAssetAddress:address(oneinch), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'GNO', baseAsset:'USD', oracleAddress:address(oracleGnoToUsd), quoteAssetAddress:address(gno), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'OMG', baseAsset:'USD', oracleAddress:address(oracleOmgToUsd), quoteAssetAddress:address(omg), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'BNT', baseAsset:'USD', oracleAddress:address(oracleBntToUsd), quoteAssetAddress:address(bnt), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CEL', baseAsset:'USD', oracleAddress:address(oracleCelToUsd), quoteAssetAddress:address(cel), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ANKR', baseAsset:'USD', oracleAddress:address(oracleAnkrToUsd), quoteAssetAddress:address(ankr), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'FXS', baseAsset:'USD', oracleAddress:address(oracleFxsToUsd), quoteAssetAddress:address(fxs), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'IMX', baseAsset:'USD', oracleAddress:address(oracleImxToUsd), quoteAssetAddress:address(imx), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'ENS', baseAsset:'USD', oracleAddress:address(oracleEnsToUsd), quoteAssetAddress:address(ens), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'SUSHI', baseAsset:'USD', oracleAddress:address(oracleSushiToUsd), quoteAssetAddress:address(sushi), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'DYDX', baseAsset:'USD', oracleAddress:address(oracleDydxToUsd), quoteAssetAddress:address(dydx), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CELR', baseAsset:'USD', oracleAddress:address(oracleCelrToUsd), quoteAssetAddress:address(celr), baseAssetIsNumeraire: true}));
    
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'PUNK', baseAsset:'USD', oracleAddress:address(oraclePunkToUsd), quoteAssetAddress:address(cryptopunks), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'BAYC', baseAsset:'USD', oracleAddress:address(oracleBaycToUsd), quoteAssetAddress:address(bayc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'MAYC', baseAsset:'USD', oracleAddress:address(oracleMaycToUsd), quoteAssetAddress:address(mayc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'CloneX', baseAsset:'USD', oracleAddress:address(oracleClonexToUsd), quoteAssetAddress:address(clonex), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LOOT', baseAsset:'USD', oracleAddress:address(oracleLootToUsd), quoteAssetAddress:address(loot), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LAND', baseAsset:'USD', oracleAddress:address(oracleSandboxnftToUsd), quoteAssetAddress:address(sandboxnft), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'COOL', baseAsset:'USD', oracleAddress:address(oracleCoolcatsToUsd), quoteAssetAddress:address(coolcats), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'AZUKI', baseAsset:'USD', oracleAddress:address(oracleAzukiToUsd), quoteAssetAddress:address(azuki), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'DOODLE', baseAsset:'USD', oracleAddress:address(oracleDoodlesToUsd), quoteAssetAddress:address(doodles), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'MEEBIT', baseAsset:'USD', oracleAddress:address(oracleMeebitsToUsd), quoteAssetAddress:address(meebits), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'KONGZ', baseAsset:'USD', oracleAddress:address(oracleCyberkongzToUsd), quoteAssetAddress:address(cyberkongz), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'BAKC', baseAsset:'USD', oracleAddress:address(oracleBakcToUsd), quoteAssetAddress:address(bakc), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'LAND', baseAsset:'USD', oracleAddress:address(oracleDecentralandToUsd), quoteAssetAddress:address(decentraland), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'TMLS', baseAsset:'USD', oracleAddress:address(oracleTimelessToUsd), quoteAssetAddress:address(timeless), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit:uint64(Constants.oracleEthToUsdUnit), baseAssetNumeraire: 0, quoteAsset:'TRV', baseAsset:'USD', oracleAddress:address(oracleFoundersplotToUsd), quoteAssetAddress:address(foundersplot), baseAssetIsNumeraire: true}));
    
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(weth)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stable)}), emptyList);

    address[] memory genOracleArr = new address[](1);
    address genAddr;
    
    genAddr = address(wbtc);
    genOracleArr[0] = address(oracleBtcToUsd);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(genAddr)}), emptyList);
    genAddr = address(wbtc);
    genOracleArr[0] = address(oracleBtcToUsd);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(genAddr)}), emptyList);
    genAddr = address(wbtc);

  
  
  
  }

}
