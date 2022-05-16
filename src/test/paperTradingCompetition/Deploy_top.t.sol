// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../paperTradingCompetition/Deploy/contracts/Deploy_coordinator.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_one.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_two.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_three.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_four.sol";

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/stdlib.sol";
import "../../../lib/forge-std/src/console.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../utils/StringHelpers.sol";

interface IVaultValue {
  function getValue(uint8) external view returns (uint256);
}

contract DeployCoordTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);  
  StdStorage private stdstore;

  DeployCoordinator public deployCoordinator;
  DeployContractsOne public deployContractsOne;
  DeployContractsTwo public deployContractsTwo;
  DeployContractsThree public deployContractsThree;
  DeployContractsFour public deployContractsFour;

  DeployCoordinator.assetInfo[] public assets;

  constructor() {

  }

  
  function testDeployAll() public {
    deployContractsOne = new DeployContractsOne();
    deployContractsTwo = new DeployContractsTwo();
    deployContractsThree = new DeployContractsThree();
    deployContractsFour = new DeployContractsFour();

    deployCoordinator = new DeployCoordinator(address(deployContractsOne),address(deployContractsTwo),address(deployContractsThree),address(deployContractsFour));

    deployCoordinator.start();

    //address oracleEthToUsd = address(deployCoordinator.oracleEthToUsd());
    //address weth = address(deployCoordinator.weth());

    //assets.push(DeployCoordinator.assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), rate: 300000000000, oracleDecimals: uint8(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", baseAsset: "USD", oracleAddr: oracleEthToUsd, assetAddr: weth}));
    
    assets.push(DeployCoordinator.assetInfo({desc: "Wrapped BTC - Mock", symbol: "mwBTC", decimals: 8, rate: 300000000000, oracleDecimals: 8, quoteAsset: "BTC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "USD Coin - Mock", symbol: "mUSDC", decimals: 6, rate: 300000000000, oracleDecimals: 8, quoteAsset: "USDC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "SHIBA INU - Mock", symbol: "mSHIB", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "SHIB", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Matic Token - Mock", symbol: "mMATIC", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "MATIC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Cronos Coin - Mock", symbol: "mCRO", decimals: 8, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CRO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Uniswap - Mock", symbol: "mUNI", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "UNI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "ChainLink Token - Mock", symbol: "mLINK", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "LINK", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "FTX Token - Mock", symbol: "mFTT", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "FTT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "ApeCoin - Mock", symbol: "mAPE", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "APE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "The Sandbox - Mock", symbol: "mSAND", decimals: 8, rate:  300000000000, oracleDecimals: 8, quoteAsset: "SAND", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Decentraland - Mock", symbol: "mMANA", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "MANA", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Axie Infinity - Mock", symbol: "mAXS", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "AXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Aave - Mock", symbol: "mAAVE", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "AAVE", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Fantom - Mock", symbol: "mFTM", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "FTM", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "KuCoin Token  - Mock", symbol: "mKCS", decimals: 6, rate: 300000000000, oracleDecimals: 8, quoteAsset: "KCS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Maker - Mock", symbol: "mMKR", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "MKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Dai - Mock", symbol: "mDAI", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "DAI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Convex Finance - Mock", symbol: "mCVX", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CVX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Curve DAO Token - Mock", symbol: "mCRV", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CRV", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Loopring - Mock", symbol: "mLRC", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "LRC", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "BAT - Mock", symbol: "mBAT", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "BAT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Amp - Mock", symbol: "mAMP", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "AMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Compound - Mock", symbol: "mCOMP", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "COMP", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "1INCH Token - Mock", symbol: "m1INCH", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "1INCH", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Gnosis - Mock", symbol: "mGNO", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "GNO", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "OMG Network - Mock", symbol: "mOMG", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "OMG", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Bancor - Mock", symbol: "mBNT", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "BNT", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Celsius Network - Mock", symbol: "mCEL", decimals: 4, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Ankr Network - Mock", symbol: "mANKR", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "ANKR", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Frax Share  - Mock", symbol: "mFXS", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "FXS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Immutable X - Mock", symbol: "mIMX", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "IMX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Ethereum Name Service  - Mock", symbol: "mENS", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "ENS", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "SushiToken - Mock", symbol: "mSUSHI", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "SUSHI", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "dYdX - Mock", symbol: "mDYDX", decimals: 18, rate:  300000000000, oracleDecimals: 8, quoteAsset: "DYDX", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "CelerToken - Mock", symbol: "mCELR", decimals: 18, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CEL", baseAsset: "USD", oracleAddr: address(0), assetAddr: address(0)}));
  
    assets.push(DeployCoordinator.assetInfo({desc: "CRYPTOPUNKS - Mock", symbol: "mC", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "PUNK", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "BoredApeYachtClub - Mock", symbol: "mBAYC", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "BAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "MutantApeYachtClub - Mock", symbol: "mMAYC", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "MAYC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "CloneX - Mock", symbol: "mCloneX", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "CloneX", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Loot - Mock", symbol: "mLOOT", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "LOOT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Sandbox's LANDs - Mock", symbol: "mLAND", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Cool Cats - Mock", symbol: "mCOOL", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "COOL", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Azuki - Mock", symbol: "mAZUKI", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "AZUKI", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Doodles - Mock", symbol: "mDOODLE", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "DOODLE", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Meebits - Mock", symbol: "mMEEBIT", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "MEEBIT", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "CyberKongz - Mock", symbol: "mKONGZ", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "KONGZ", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "BoredApeKennelClub - Mock", symbol: "mBAKC", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "BAKC", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Decentraland LAND - Mock", symbol: "mLAND", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "LAND", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Timeless - Mock", symbol: "mTMLS", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "TMLS", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
    assets.push(DeployCoordinator.assetInfo({desc: "Treeverse - Mock", symbol: "mTRV", decimals: 0, rate: 300000000000, oracleDecimals: 8, quoteAsset: "TRV", baseAsset: "ETH", oracleAddr: address(0), assetAddr: address(0)}));
  


    deployCoordinator.storeAssets(assets);

    deployCoordinator.deployERC20Contracts();
    deployCoordinator.deployERC721Contracts();
    deployCoordinator.deployOracles();
    deployCoordinator.setOracleAnswers();
    deployCoordinator.addOracles();
    emit log_named_address("OracleEThToUsd", address(deployCoordinator.oracleEthToUsd()));
    checkOracle();
    deployCoordinator.setAssetInformation();

    deployCoordinator.verifyView();

    deployCoordinator.createNewVaultThroughDeployer(address(this));


    vm.startPrank(address(3));
    address firstVault = IFactoryPaperTradingExtended(deployCoordinator.factory()).createVault(125498456465, 0);
    address secondVault = IFactoryPaperTradingExtended(deployCoordinator.factory()).createVault(125498456465545885545, 1);
    vm.stopPrank();

    emit log_named_uint("vault1value", IVaultValue(firstVault).getValue(0));
    emit log_named_uint("vault1value", IVaultValue(secondVault).getValue(1));
  }

  function checkOracle() public {
    uint256 len = assets.length;
    address oracleAddr_t;
    string memory symb;
    for (uint i; i < len; ++i) {
      (,,,,symb,,,oracleAddr_t,) = deployCoordinator.assets(i);
      if (StringHelpers.compareStrings(symb, "mwETH")) {
        emit log_named_address("Orac from assets", oracleAddr_t);
      }
    }
  }


  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

}