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
    uint8 oracleDecimals;
    uint128 rate;
    string tradePair;
    string quoteAsset;
    address oracleAddr;
    address assetAddr;
  }

  assetInfo[] public assets;
  function storeStructs() public onlyOwner {
    assets.push(assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), tradePair: "ETH / USD", rate: uint128(rateEthToUsd), oracleDecimals: uint8(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    
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

  function deployOracles() public onlyOwner {
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      newContr = address(new SimplifiedChainlinkOracle(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD"))));
      assets[i].oracleAddr = newContr;
    }

    oracleStableToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "STABLE / USD");
    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);
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

    oracleHub.addOracle(OracleHub.OracleInformation({oracleUnit: uint64(10**18), baseAssetNumeraire: 0, quoteAsset: "STABLE", baseAsset: "USD", oracleAddress: address(oracleStableToUsd), quoteAssetAddress: address(0), baseAssetIsNumeraire: true}));

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
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stable)}), emptyList);

  }

}
