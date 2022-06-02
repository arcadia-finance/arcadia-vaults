// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../Proxy.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../utils/Constants.sol";
import "../../paperTradingCompetition/Oracles/StableOracle.sol";
import "../../mockups/SimplifiedChainlinkOracle.sol";

import "../../AssetRegistry/MainRegistry.sol";
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



contract DeployScript is DSTest, Script {


  FactoryPaperTrading public factory;
  Vault public vault;
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
  LiquidatorPaperTrading public liquidator;
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

  struct assetInfo {
    uint8 decimals;
    uint8 oracleDecimals;
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
    SimplifiedChainlinkOracle(oracleAddr).setAnswer(int256(amount));
  }


  // function deploy() public {
  //   vm.startBroadcast();
  //   startTest();
  //   vm.stopBroadcast();
  // }

  function run() public {
    vm.startBroadcast();
    start();

    vm.stopBroadcast();
  }

  //1. start()
  //2. deployer.storeAssets()
  // [[8, 8, "2934300000000", "Mocked Wrapped BTC", "mwBTC", "BTC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "100000000", "Mocked USD Coin", "mUSDC", "USDC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1179", "Mocked SHIBA INU", "mSHIB", "SHIB", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6460430", "Mocked Matic Token", "mMATIC", "MATIC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "1872500", "Mocked Cronos Coin", "mCRO", "CRO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "567000000", "Mocked Uniswap", "mUNI", "UNI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "706000000", "Mocked ChainLink Token", "mLINK", "LINK", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2976000000", "Mocked FTX Token", "mFTT", "FTT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "765000000", "Mocked ApeCoin", "mAPE", "APE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "130000000", "Mocked The Sandbox", "mSAND", "SAND", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "103000000", "Mocked Decentraland", "mMANA", "MANA", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2107000000", "Mocked Axie Infinity", "mAXS", "AXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9992000000", "Mocked Aave", "mAAVE", "AAVE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "4447550", "Mocked Fantom", "mFTM", "FTM", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "1676000000", "Mocked KuCoin Token ", "mKCS", "KCS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "131568000000", "Mocked Maker", "mMKR", "MKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "100000000", "Mocked Dai", "mDAI", "DAI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1028000000", "Mocked Convex Finance", "mCVX", "CVX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "128000000", "Mocked Curve DAO Token", "mCRV", "CRV", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "5711080", "Mocked Loopring", "mLRC", "LRC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "3913420", "Mocked BAT", "mBAT", "BAT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "13226", "Mocked Amp", "mAMP", "AMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6943000000", "Mocked Compound", "mCOMP", "COMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9926070", "Mocked 1INCH Token", "m1INCH", "1INCH", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "21117000000", "Mocked Gnosis", "mGNO", "GNO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "257000000", "Mocked OMG Network", "mOMG", "OMG", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "138000000", "Mocked Bancor", "mBNT", "BNT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [4, 8, "7629100", "Mocked Celsius Network", "mCEL", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "392627", "Mocked Ankr Network", "mANKR", "ANKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "721000000", "Mocked Frax Share ", "mFXS", "FXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9487620", "Mocked Immutable X", "mIMX", "IMX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1238000000", "Mocked Ethereum Name Service ", "mENS", "ENS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "166000000", "Mocked SushiToken", "mSUSHI", "SUSHI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "206000000", "Mocked Mocked dYdX", "mDYDX", "DYDX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "186335", "Mocked CelerToken", "mCELR", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "48950000000000000000", "Mocked CRYPTOPUNKS", "mC", "PUNK", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "93990000000000000000", "Mocked BoredApeYachtClub", "mBAYC", "BAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "18850000000000000000", "Mocked MutantApeYachtClub", "mMAYC", "MAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "14400000000000000000", "Mocked CloneX", "mCloneX", "CloneX", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1100000000000000000", "Mocked Loot", "mLOOT", "LOOT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1630000000000000000", "Mocked Sandbox's LANDs", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "3490000000000000000", "Mocked Cool Cats", "mCOOL", "COOL", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12700000000000000000", "Mocked Azuki", "mAZUKI", "AZUKI", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12690000000000000000", "Mocked Doodles", "mDOODLE", "DOODLE", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "4600000000000000000", "Mocked Meebits", "mMEEBIT", "MEEBIT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2760000000000000000", "Mocked CyberKongz", "mKONGZ", "KONGZ", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "7200000000000000000", "Mocked BoredApeKennelClub", "mBAKC", "BAKC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2000000000000000000", "Mocked Decentraland LAND", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "380000000000000000", "Mocked Timeless", "mTMLS", "TMLS", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "10500000000000000000", "Mocked Treeverse", "mTRV", "TRV", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"]]
  //3  continue in order

  function start() public {
    factory = new FactoryPaperTrading();
    factory.setBaseURI("ipfs://");

    stableUsd = new StablePaperTrading("Mocked Arcadia USD", "maUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    stableEth = new StablePaperTrading("Mocked Arcadia ETH", "maETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory));

    oracleEthToUsd = new SimplifiedChainlinkOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableUsdToUsd = new StableOracle(uint8(Constants.oracleStableToUsdDecimals), "maUSD / USD");
    oracleStableEthToEth = new StableOracle(uint8(Constants.oracleStableEthToEthUnit), "maETH / ETH");

    mainRegistry = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));

    liquidator = new LiquidatorPaperTrading(address(factory), address(mainRegistry));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    tokenShop = new TokenShop(address(mainRegistry));
    tokenShop.setFactory(address(factory));
    weth = new ERC20PaperTrading("Mocked Wrapped ETH", "mETH", uint8(Constants.ethDecimals), address(tokenShop));

    stableUsd.setTokenShop(address(tokenShop));
    stableEth.setTokenShop(address(tokenShop));

    oracleHub = new OracleHub();

    standardERC20Registry = new StandardERC20Registry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = new FloorERC721SubRegistry(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(floorERC721Registry));

    interestRateModule = new InterestRateModule();
    interestRateModule.setBaseInterestRate(5 * 10 **16);

    vault = new VaultPaperTrading();
    factory.setNewVaultInfo(address(mainRegistry), address(vault), stakeContract, address(interestRateModule));
    factory.confirmNewVaultInfo();
    factory.setLiquidator(address(liquidator));
    factory.setTokenShop(address(tokenShop));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));

    storeAssets();

    deployERC20Contracts();
    deployERC721Contracts();
    deployOracles();
    setOracleAnswers();
    addOracles();
    setAssetInformation();

  }

  // [[8, 8, "2934300000000", "Mocked Wrapped BTC", "mwBTC", "BTC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "100000000", "Mocked USD Coin", "mUSDC", "USDC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1179", "Mocked SHIBA INU", "mSHIB", "SHIB", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6460430", "Mocked Matic Token", "mMATIC", "MATIC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "1872500", "Mocked Cronos Coin", "mCRO", "CRO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "567000000", "Mocked Uniswap", "mUNI", "UNI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "706000000", "Mocked ChainLink Token", "mLINK", "LINK", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2976000000", "Mocked FTX Token", "mFTT", "FTT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "765000000", "Mocked ApeCoin", "mAPE", "APE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "130000000", "Mocked The Sandbox", "mSAND", "SAND", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "103000000", "Mocked Decentraland", "mMANA", "MANA", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2107000000", "Mocked Axie Infinity", "mAXS", "AXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9992000000", "Mocked Aave", "mAAVE", "AAVE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "4447550", "Mocked Fantom", "mFTM", "FTM", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "1676000000", "Mocked KuCoin Token ", "mKCS", "KCS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "131568000000", "Mocked Maker", "mMKR", "MKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "100000000", "Mocked Dai", "mDAI", "DAI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1028000000", "Mocked Convex Finance", "mCVX", "CVX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "128000000", "Mocked Curve DAO Token", "mCRV", "CRV", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "5711080", "Mocked Loopring", "mLRC", "LRC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "3913420", "Mocked BAT", "mBAT", "BAT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "13226", "Mocked Amp", "mAMP", "AMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6943000000", "Mocked Compound", "mCOMP", "COMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9926070", "Mocked 1INCH Token", "m1INCH", "1INCH", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "21117000000", "Mocked Gnosis", "mGNO", "GNO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "257000000", "Mocked OMG Network", "mOMG", "OMG", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "138000000", "Mocked Bancor", "mBNT", "BNT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [4, 8, "7629100", "Mocked Celsius Network", "mCEL", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "392627", "Mocked Ankr Network", "mANKR", "ANKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "721000000", "Mocked Frax Share ", "mFXS", "FXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9487620", "Mocked Immutable X", "mIMX", "IMX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1238000000", "Mocked Ethereum Name Service ", "mENS", "ENS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "166000000", "Mocked SushiToken", "mSUSHI", "SUSHI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "206000000", "Mocked Mocked dYdX", "mDYDX", "DYDX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "186335", "Mocked CelerToken", "mCELR", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "48950000000000000000", "Mocked CRYPTOPUNKS", "mC", "PUNK", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "93990000000000000000", "Mocked BoredApeYachtClub", "mBAYC", "BAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "18850000000000000000", "Mocked MutantApeYachtClub", "mMAYC", "MAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "14400000000000000000", "Mocked CloneX", "mCloneX", "CloneX", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1100000000000000000", "Mocked Loot", "mLOOT", "LOOT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1630000000000000000", "Mocked Sandbox's LANDs", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "3490000000000000000", "Mocked Cool Cats", "mCOOL", "COOL", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12700000000000000000", "Mocked Azuki", "mAZUKI", "AZUKI", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12690000000000000000", "Mocked Doodles", "mDOODLE", "DOODLE", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "4600000000000000000", "Mocked Meebits", "mMEEBIT", "MEEBIT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2760000000000000000", "Mocked CyberKongz", "mKONGZ", "KONGZ", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "7200000000000000000", "Mocked BoredApeKennelClub", "mBAKC", "BAKC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2000000000000000000", "Mocked Decentraland LAND", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "380000000000000000", "Mocked Timeless", "mTMLS", "TMLS", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "10500000000000000000", "Mocked Treeverse", "mTRV", "TRV", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"]]
  // function storeAssetsAll(assetInfo[] calldata _assets) public {
  //   storeAssets();
  // }

  function deployERC20Contracts() public {
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

  function deployERC721Contracts() public {
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

  function deployOracles() public {
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (!StringHelpers.compareStrings(asset.symbol, "mwETH")) {
        newContr = address(new SimplifiedChainlinkOracle(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD"))));
        assets[i].oracleAddr = newContr;
      }
    }

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableEth), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

  }

  function setOracleAnswers() public {
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      SimplifiedChainlinkOracle(asset.oracleAddr).setAnswer(int256(uint256(asset.rate)));
    }
  }

  function addOracles() public {
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

  }

  function setAssetInformation() public {
    assetInfo memory asset;
    uint256[] memory emptyList = new uint256[](0);
    address[] memory genOracleArr1 = new address[](1);
    address[] memory genOracleArr2 = new address[](2);
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (StringHelpers.compareStrings(asset.baseAsset, "ETH")) {
        genOracleArr2[0] = asset.oracleAddr;
        genOracleArr2[1] = address(oracleEthToUsd);

        if (asset.decimals == 0) {
          floorERC721Registry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: genOracleArr2, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), emptyList);
        }
        else {
          standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr2, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), emptyList);
          }
      }
      else {
        genOracleArr1[0] = asset.oracleAddr;

        if (asset.decimals == 0) {
          floorERC721Registry.setAssetInformation(FloorERC721SubRegistry.AssetInformation({oracleAddresses: genOracleArr1, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), emptyList);
        }
        else {
          standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: genOracleArr1, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), emptyList);
          }
      }

    }

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    address[] memory oracleStableUsdToUsdArr = new address[](1);    
    oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);

    address[] memory oracleStableEthToUsdArr = new address[](2);
    oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
    oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(weth)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableUsdToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stableUsd)}), emptyList);
    standardERC20Registry.setAssetInformation(StandardERC20Registry.AssetInformation({oracleAddresses: oracleStableEthToUsdArr, assetUnit: uint64(10**Constants.stableEthDecimals), assetAddress: address(stableEth)}), emptyList);


  }

  function storeAssets() internal {
    assets.push(assetInfo({desc: "Mocked Wrapped Ether", symbol: "mwETH", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ETH", baseAsset: "USD", oracleAddr: address(oracleEthToUsd), assetAddr: address(weth)}));
    assets.push(assetInfo({desc: "Mocked Wrapped BTC", symbol: "mwBTC", decimals: 8, rate: 2934300000000, oracleDecimals: 8, quoteAsset: "BTC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked USD Coin", symbol: "mUSDC", decimals: 6, rate: 100000000, oracleDecimals: 8, quoteAsset: "USDC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked SHIBA INU", symbol: "mSHIB", decimals: 18, rate: 1179, oracleDecimals: 8, quoteAsset: "SHIB", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Matic Token", symbol: "mMATIC", decimals: 18, rate: 6460430, oracleDecimals: 8, quoteAsset: "MATIC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Cronos Coin", symbol: "mCRO", decimals: 8, rate: 1872500, oracleDecimals: 8, quoteAsset: "CRO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Uniswap", symbol: "mUNI", decimals: 18, rate: 567000000, oracleDecimals: 8, quoteAsset: "UNI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked ChainLink Token", symbol: "mLINK", decimals: 18, rate: 706000000, oracleDecimals: 8, quoteAsset: "LINK", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked FTX Token", symbol: "mFTT", decimals: 18, rate: 2976000000, oracleDecimals: 8, quoteAsset: "FTT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked ApeCoin", symbol: "mAPE", decimals: 18, rate: 765000000, oracleDecimals: 8, quoteAsset: "APE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked The Sandbox", symbol: "mSAND", decimals: 8, rate: 130000000, oracleDecimals: 8, quoteAsset: "SAND", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Decentraland", symbol: "mMANA", decimals: 18, rate: 103000000, oracleDecimals: 8, quoteAsset: "MANA", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Axie Infinity", symbol: "mAXS", decimals: 18, rate: 2107000000, oracleDecimals: 8, quoteAsset: "AXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Aave", symbol: "mAAVE", decimals: 18, rate: 9992000000, oracleDecimals: 8, quoteAsset: "AAVE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Fantom", symbol: "mFTM", decimals: 18, rate: 4447550, oracleDecimals: 8, quoteAsset: "FTM", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked KuCoin Token ", symbol: "mKCS", decimals: 6, rate: 1676000000, oracleDecimals: 8, quoteAsset: "KCS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Maker", symbol: "mMKR", decimals: 18, rate: 131568000000, oracleDecimals: 8, quoteAsset: "MKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Dai", symbol: "mDAI", decimals: 18, rate: 100000000, oracleDecimals: 8, quoteAsset: "DAI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Convex Finance", symbol: "mCVX", decimals: 18, rate: 1028000000, oracleDecimals: 8, quoteAsset: "CVX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Curve DAO Token", symbol: "mCRV", decimals: 18, rate: 128000000, oracleDecimals: 8, quoteAsset: "CRV", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Loopring", symbol: "mLRC", decimals: 18, rate: 5711080, oracleDecimals: 8, quoteAsset: "LRC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BAT", symbol: "mBAT", decimals: 18, rate: 3913420, oracleDecimals: 8, quoteAsset: "BAT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Amp", symbol: "mAMP", decimals: 18, rate: 13226, oracleDecimals: 8, quoteAsset: "AMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Compound", symbol: "mCOMP", decimals: 18, rate: 6943000000, oracleDecimals: 8, quoteAsset: "COMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked 1INCH Token", symbol: "m1INCH", decimals: 18, rate: 9926070, oracleDecimals: 8, quoteAsset: "1INCH", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Gnosis", symbol: "mGNO", decimals: 18, rate: 21117000000, oracleDecimals: 8, quoteAsset: "GNO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked OMG Network", symbol: "mOMG", decimals: 18, rate: 257000000, oracleDecimals: 8, quoteAsset: "OMG", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Bancor", symbol: "mBNT", decimals: 18, rate: 138000000, oracleDecimals: 8, quoteAsset: "BNT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Celsius Network", symbol: "mCEL", decimals: 4, rate: 7629100, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Ankr Network", symbol: "mANKR", decimals: 18, rate: 392627, oracleDecimals: 8, quoteAsset: "ANKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Frax Share ", symbol: "mFXS", decimals: 18, rate: 721000000, oracleDecimals: 8, quoteAsset: "FXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Immutable X", symbol: "mIMX", decimals: 18, rate: 9487620, oracleDecimals: 8, quoteAsset: "IMX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Ethereum Name Service ", symbol: "mENS", decimals: 18, rate: 1238000000, oracleDecimals: 8, quoteAsset: "ENS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked SushiToken", symbol: "mSUSHI", decimals: 18, rate: 166000000, oracleDecimals: 8, quoteAsset: "SUSHI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Mocked dYdX", symbol: "mDYDX", decimals: 18, rate: 206000000, oracleDecimals: 8, quoteAsset: "DYDX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CelerToken", symbol: "mCELR", decimals: 18, rate: 186335, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(assetInfo({desc: "Mocked CRYPTOPUNKS", symbol: "mC", decimals: 0, rate: 48950000000000000000, oracleDecimals: 18, quoteAsset: "PUNK", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BoredApeYachtClub", symbol: "mBAYC", decimals: 0, rate: 93990000000000000000, oracleDecimals: 18, quoteAsset: "BAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked MutantApeYachtClub", symbol: "mMAYC", decimals: 0, rate: 18850000000000000000, oracleDecimals: 18, quoteAsset: "MAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CloneX", symbol: "mCloneX", decimals: 0, rate: 14400000000000000000, oracleDecimals: 18, quoteAsset: "CloneX", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Loot", symbol: "mLOOT", decimals: 0, rate: 1100000000000000000, oracleDecimals: 18, quoteAsset: "LOOT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Sandbox's LANDs", symbol: "mLAND", decimals: 0, rate: 1630000000000000000, oracleDecimals: 18, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Cool Cats", symbol: "mCOOL", decimals: 0, rate: 3490000000000000000, oracleDecimals: 18, quoteAsset: "COOL", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Azuki", symbol: "mAZUKI", decimals: 0, rate: 12700000000000000000, oracleDecimals: 18, quoteAsset: "AZUKI", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Doodles", symbol: "mDOODLE", decimals: 0, rate: 12690000000000000000, oracleDecimals: 18, quoteAsset: "DOODLE", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Meebits", symbol: "mMEEBIT", decimals: 0, rate: 4600000000000000000, oracleDecimals: 18, quoteAsset: "MEEBIT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked CyberKongz", symbol: "mKONGZ", decimals: 0, rate: 2760000000000000000, oracleDecimals: 18, quoteAsset: "KONGZ", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked BoredApeKennelClub", symbol: "mBAKC", decimals: 0, rate: 7200000000000000000, oracleDecimals: 18, quoteAsset: "BAKC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Decentraland LAND", symbol: "mLAND", decimals: 0, rate: 2000000000000000000, oracleDecimals: 18, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Timeless", symbol: "mTMLS", decimals: 0, rate: 380000000000000000, oracleDecimals: 18, quoteAsset: "TMLS", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Mocked Treeverse", symbol: "mTRV", decimals: 0, rate: 10500000000000000000, oracleDecimals: 18, quoteAsset: "TRV", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
  
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