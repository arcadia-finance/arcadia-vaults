// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../../utils/Strings.sol";
import "../../../utils/Constants.sol";


interface ICoordinator {
  struct assetInfo {
    string desc;
    string symbol;
    uint8 decimals;
    uint8 oracleDecimals;
    uint128 rate;
    string quoteAsset;
    string baseAsset;
    address oracleAddr;
    address assetAddr;
  }
  function acceptStoring(assetInfo calldata) external;
}

contract DeployContractsAssets  {
  
  address public owner;

  uint256 rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;

  address[] public oracleEthToUsdArr = new address[](1);
  address[] public oracleStableToUsdArr = new address[](1);

  address oracleEthToUsd;
  address weth;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;

  }

  function setAddr(address _oracleEthToUsd, address _weth) public onlyOwner {
      oracleEthToUsd = _oracleEthToUsd;
      weth = _weth;
  }
  
  function storeAssets() public onlyOwner {
    assets.push(assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), rate: uint128(rateEthToUsd), oracleDecimals: uint8(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", baseAsset: "USD", oracleAddr: oracleEthToUsd, assetAddr: weth}));
    
    assets.push(assetInfo({desc: "Wrapped BTC - Mock", symbol: "mwBTC", decimals: 8, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BTC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "USD Coin - Mock", symbol: "mUSDC", decimals: 6, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "USDC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SHIBA INU - Mock", symbol: "mSHIB", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SHIB", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Matic Token - Mock", symbol: "mMATIC", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MATIC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cronos Coin - Mock", symbol: "mCRO", decimals: 8, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Uniswap - Mock", symbol: "mUNI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "UNI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ChainLink Token - Mock", symbol: "mLINK", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LINK", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "FTX Token - Mock", symbol: "mFTT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "ApeCoin - Mock", symbol: "mAPE", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "APE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "The Sandbox - Mock", symbol: "mSAND", decimals: 8, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SAND", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland - Mock", symbol: "mMANA", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MANA", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Axie Infinity - Mock", symbol: "mAXS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Aave - Mock", symbol: "mAAVE", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AAVE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Fantom - Mock", symbol: "mFTM", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FTM", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "KuCoin Token  - Mock", symbol: "mKCS", decimals: 6, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KCS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Maker - Mock", symbol: "mMKR", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Dai - Mock", symbol: "mDAI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DAI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Convex Finance - Mock", symbol: "mCVX", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CVX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Curve DAO Token - Mock", symbol: "mCRV", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CRV", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loopring - Mock", symbol: "mLRC", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LRC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BAT - Mock", symbol: "mBAT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Amp - Mock", symbol: "mAMP", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Compound - Mock", symbol: "mCOMP", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "1INCH Token - Mock", symbol: "m1INCH", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "1INCH", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Gnosis - Mock", symbol: "mGNO", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "GNO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "OMG Network - Mock", symbol: "mOMG", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "OMG", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Bancor - Mock", symbol: "mBNT", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BNT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Celsius Network - Mock", symbol: "mCEL", decimals: 4, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ankr Network - Mock", symbol: "mANKR", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ANKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Frax Share  - Mock", symbol: "mFXS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "FXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Immutable X - Mock", symbol: "mIMX", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "IMX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Ethereum Name Service  - Mock", symbol: "mENS", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "ENS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "SushiToken - Mock", symbol: "mSUSHI", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "SUSHI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "dYdX - Mock", symbol: "mDYDX", decimals: 18, rate:  uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DYDX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CelerToken - Mock", symbol: "mCELR", decimals: 18, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(assetInfo({desc: "CRYPTOPUNKS - Mock", symbol: "mC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "PUNK", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeYachtClub - Mock", symbol: "mBAYC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "MutantApeYachtClub - Mock", symbol: "mMAYC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CloneX - Mock", symbol: "mCloneX", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "CloneX", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Loot - Mock", symbol: "mLOOT", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LOOT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Sandbox's LANDs - Mock", symbol: "mLAND", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Cool Cats - Mock", symbol: "mCOOL", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "COOL", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Azuki - Mock", symbol: "mAZUKI", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "AZUKI", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Doodles - Mock", symbol: "mDOODLE", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "DOODLE", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Meebits - Mock", symbol: "mMEEBIT", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "MEEBIT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "CyberKongz - Mock", symbol: "mKONGZ", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "KONGZ", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "BoredApeKennelClub - Mock", symbol: "mBAKC", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "BAKC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Decentraland LAND - Mock", symbol: "mLAND", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Timeless - Mock", symbol: "mTMLS", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TMLS", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(assetInfo({desc: "Treeverse - Mock", symbol: "mTRV", decimals: 0, rate: uint128(rateEthToUsd), oracleDecimals: 8, quoteAsset: "TRV", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
  
  }

  struct assetInfo {
    string desc;
    string symbol;
    uint8 decimals;
    uint8 oracleDecimals;
    uint128 rate;
    string quoteAsset;
    string baseAsset;
    address oracleAddr;
    address assetAddr;
  }

  assetInfo[] public assets;


  function assetLength() public view returns (uint256) {
    return assets.length;
  }

  function transferAssets(address coordAdr) public onlyOwner {
    for (uint i; i < assets.length; ++i) {
      ICoordinator(coordAdr).acceptStoring(ICoordinator.assetInfo(assets[i].desc, 
                                                                   assets[i].symbol, 
                                                                   assets[i].decimals,
                                                                   assets[i].oracleDecimals,
                                                                   assets[i].rate,
                                                                   assets[i].quoteAsset,
                                                                   assets[i].baseAsset,
                                                                   assets[i].oracleAddr,
                                                                   assets[i].assetAddr));
    }
  }
  
}
