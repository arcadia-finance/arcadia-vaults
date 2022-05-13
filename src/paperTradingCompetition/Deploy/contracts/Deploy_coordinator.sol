// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;


import "../../interfaces/IERC20PaperTrading.sol";
import "../../interfaces/IERC721PaperTrading.sol";
import "../../interfaces/IERC1155PaperTrading.sol";
import "../../interfaces/IFactoryPaperTrading.sol";
import "../../interfaces/IVaultPaperTrading.sol";
import "../../interfaces/ITokenShop.sol";
import "../../../interfaces/IOraclesHub.sol";
import "../../../interfaces/IMainRegistry.sol";
import "../../../interfaces/IRegistry.sol";
import "../../../interfaces/IRM.sol";
import "../../../interfaces/IRM.sol";
import "../../../interfaces/IStable.sol";
import "../../../interfaces/IChainLinkData.sol";
import "../../../interfaces/ILiquidator.sol";

import "../../../utils/Constants.sol";
import "../../../utils/Strings.sol";


interface IDeployerOne {
  function deployFact() external returns (address);
  function deployStable(string calldata, string calldata, uint8, address, address) external returns (address);
  function deployOracle(uint8, string calldata) external returns (address);
  function deployOracleStable(uint8, string calldata) external returns (address);
}

interface IDeployerTwo {
  struct NumeraireInformation {
    uint64 numeraireToUsdOracleUnit;
    uint64 numeraireUnit;
    address assetAddress;
    address numeraireToUsdOracle;
    address stableAddress;
    string numeraireLabel;
  }

  function deployMainReg(NumeraireInformation calldata) external returns (address);
  function deployLiquidator(address, address, address) external returns (address);
  function deployTokenShop(address) external returns (address);
}

interface IDeployerThree {
  function deployERC20(string calldata, string calldata, uint8, address) external returns (address);
  function deployERC721(string calldata, string calldata, address) external returns (address);
  function deployOracHub() external returns (address);
  function deployERC20SubReg(address, address) external returns (address);
  function deployERC721SubReg(address, address) external returns (address);
}

interface IDeployerFour {
  function deployIRM() external returns (address);
  function deployVaultLogic() external returns (address);


}

interface IFactoryPaperTradingExtended is IFactoryPaperTrading {
  function setBaseURI(string memory) external;
  function setNewVaultInfo(address, address, address, address) external;
  function confirmNewVaultInfo() external;
  function setLiquidator(address) external;
  function createVault(uint256, uint256) external returns (address);
  function baseURI() external view returns (string memory);
  function liquidatorAddress() external view returns (address);
  function newVaultInfoSet() external view returns (bool);
  function currentVaultVersion() external view returns (uint256);
  function vaultDetails(uint256) external view returns (address, address, address, address);
  function numeraireToStable(uint256) external view returns (address);
  function numeraireCounter() external view returns (uint256);
}

interface IStablePaperTradingExtended is IStable {
  function setLiquidator(address) external;
  function liquidator() external view returns (address);
  function factory() external view returns (address);
}

interface IOraclePaperTradingExtended is IChainLinkData {
  function setAnswer(int256) external;

  struct OracleInformation {
    uint64 oracleUnit;
    uint8 baseAssetNumeraire;
    bool baseAssetIsNumeraire;
    string quoteAsset;
    string baseAsset;
    address oracleAddress;
    address quoteAssetAddress;
  }
}

interface IMainRegistryExtended is IMainRegistry {
  function addSubRegistry(address) external;
  function setFactory(address) external;
  function isSubRegistry(address) external view returns (bool);
  function numeraireCounter() external view returns (uint256);

  struct NumeraireInformation {
    uint64 numeraireToUsdOracleUnit;
    uint64 numeraireUnit;
    address assetAddress;
    address numeraireToUsdOracle;
    address stableAddress;
    string numeraireLabel;
  }

  function addNumeraire(NumeraireInformation calldata, uint256[] calldata) external;
}


interface ILiquidatorPaperTradingExtended is ILiquidator {
  function setFactory(address) external;
  function registryAddress() external view returns (address);
  function factoryAddress() external view returns (address);
  function stable() external view returns (address);
}

interface IOracleHubExtended is IOraclesHub {
  struct OracleInformation {
    uint64 oracleUnit;
    uint8 baseAssetNumeraire;
    bool baseAssetIsNumeraire;
    string quoteAsset;
    string baseAsset;
    address oracleAddress;
    address quoteAssetAddress;
  }

  function addOracle(OracleInformation calldata) external;
}

interface IErc20SubRegistry {
  struct AssetInformation {
    uint64 assetUnit;
    address assetAddress;
    address[] oracleAddresses;
  }
}

interface IErc721SubRegistry {
  struct AssetInformation {
    uint256 idRangeStart;
    uint256 idRangeEnd;
    address assetAddress;
    address[] oracleAddresses;
  }
}

interface IRegistryExtended is IRegistry {
  function setAssetInformation(IErc721SubRegistry.AssetInformation calldata, uint256[] calldata) external;
  function setAssetInformation(IErc20SubRegistry.AssetInformation calldata, uint256[] calldata) external;
  function _mainRegistry() external view returns (address);
  function _oracleHub() external view returns (address);

}

interface IIRMExtended is IRM {
  function setBaseInterestRate(uint64) external;
}

interface ITokenShopExtended is ITokenShop {
  function mainRegistry() external view returns (address);
}


contract DeployCoordinator {

  IDeployerOne public deployerOne;
  IDeployerTwo public deployerTwo;
  IDeployerThree public deployerThree;
  IDeployerFour public deployerFour;

  IFactoryPaperTradingExtended public factory;
  IVaultPaperTrading public vault;
  IVaultPaperTrading public proxy;
  address public proxyAddr;
  
  IOracleHubExtended public oracleHub;
  IMainRegistryExtended public mainRegistry;
  IRegistryExtended public standardERC20Registry;
  IRegistryExtended public floorERC721Registry;
  IIRMExtended public interestRateModule;
  IStablePaperTradingExtended public stableUsd;
  IStablePaperTradingExtended public stableEth;
  IOraclePaperTradingExtended public oracleStableUsdToUsd;
  IOraclePaperTradingExtended public oracleStableEthToEth;
  ILiquidatorPaperTradingExtended public liquidator;
  ITokenShopExtended public tokenShop;

  IERC20PaperTrading public weth;

  IOraclePaperTradingExtended public oracleEthToUsd;

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

  address public assetMgr;

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


  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor(address _deployerOne, address _deployerTwo, address _deployerThree, address _deployerFour, address _assetMgr) {
    owner = msg.sender;
    deployerOne = IDeployerOne(_deployerOne);
    deployerTwo = IDeployerTwo(_deployerTwo);
    deployerThree = IDeployerThree(_deployerThree);
    deployerFour = IDeployerFour(_deployerFour);
    assetMgr = _assetMgr;
  }

  function createNewVaultThroughDeployer(address newVaultOwner) public onlyOwner {
    proxyAddr = factory.createVault(uint256(keccak256(abi.encodeWithSignature("doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)))), 0);
    factory.safeTransferFrom(address(this), newVaultOwner, factory.vaultIndex(address(proxyAddr)));
  }
  

  //1. start()
  //2. deployerAssets.setAddr(addr, addr)
  //3. deployerAssets.storeAssets()
  //4. deployerAssets.transferAssets()
  //5  continue here

  function start() public onlyOwner {
    factory = IFactoryPaperTradingExtended(deployerOne.deployFact());
    factory.setBaseURI("ipfs://");

    stableUsd = IStablePaperTradingExtended(deployerOne.deployStable("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory)));
    stableEth = IStablePaperTradingExtended(deployerOne.deployStable("Arcadia ETH Stable Mock", "masETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory)));

    oracleEthToUsd = IOraclePaperTradingExtended(deployerOne.deployOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD"));
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableUsdToUsd = IOraclePaperTradingExtended(deployerOne.deployOracleStable(uint8(Constants.oracleStableToUsdDecimals), "masUSD / USD"));
    oracleStableEthToEth = IOraclePaperTradingExtended(deployerOne.deployOracleStable(uint8(Constants.oracleStableEthToEthUnit), "masEth / Eth"));

    mainRegistry = IMainRegistryExtended(deployerTwo.deployMainReg(IDeployerTwo.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1})));

    liquidator = ILiquidatorPaperTradingExtended(deployerTwo.deployLiquidator(address(factory), address(mainRegistry), address(stableUsd)));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    tokenShop = ITokenShopExtended(deployerTwo.deployTokenShop(address(mainRegistry)));
    weth = IERC20PaperTrading(deployerThree.deployERC20("ETH Mock", "mETH", uint8(Constants.ethDecimals), address(tokenShop)));

    oracleHub = IOracleHubExtended(deployerThree.deployOracHub());

    standardERC20Registry = IRegistryExtended(deployerThree.deployERC20SubReg(address(mainRegistry), address(oracleHub)));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = IRegistryExtended(deployerThree.deployERC721SubReg(address(mainRegistry), address(oracleHub)));
    mainRegistry.addSubRegistry(address(floorERC721Registry));

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableToUsdArr[0] = address(oracleStableUsdToUsd);

    interestRateModule = IIRMExtended(deployerFour.deployIRM());
    interestRateModule.setBaseInterestRate(5 * 10 **16);

    vault = IVaultPaperTrading(deployerFour.deployVaultLogic());
    factory.setNewVaultInfo(address(mainRegistry), address(vault), stakeContract, address(interestRateModule));
    factory.confirmNewVaultInfo();
    factory.setLiquidator(address(liquidator));
    liquidator.setFactory(address(factory));
    mainRegistry.setFactory(address(factory));

  }

  function acceptStoring(assetInfo calldata asset) public {
    require(msg.sender == assetMgr, "Not assetMgr");
    assets.push(asset);
  }

  function deployERC20Contracts() public onlyOwner {
    address newContr;
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      if (asset.decimals == 0) { }
      else {
        if (asset.assetAddr == address(0)) {
          newContr = deployerThree.deployERC20(asset.desc, asset.symbol, asset.decimals, address(tokenShop));
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
        newContr = deployerThree.deployERC721(asset.desc, asset.symbol, address(tokenShop));
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
      newContr = deployerOne.deployOracle(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD")));
      assets[i].oracleAddr = newContr;
    }

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(IMainRegistryExtended.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableEth), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

  }

  function setOracleAnswers() public onlyOwner {
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      IOraclePaperTradingExtended(asset.oracleAddr).setAnswer(int256(uint256(asset.rate)));
    }
  }

  function addOracles() public onlyOwner {
    assetInfo memory asset;
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      oracleHub.addOracle(IOracleHubExtended.OracleInformation({oracleUnit: uint64(10**asset.oracleDecimals), baseAssetNumeraire: 0, quoteAsset: asset.quoteAsset, baseAsset: "USD", oracleAddress: asset.oracleAddr, quoteAssetAddress: asset.assetAddr, baseAssetIsNumeraire: true}));
    }

    oracleHub.addOracle(IOracleHubExtended.OracleInformation({oracleUnit: uint64(Constants.oracleStableToUsdUnit), baseAssetNumeraire: 0, quoteAsset: "masUSD", baseAsset: "USD", oracleAddress: address(oracleStableUsdToUsd), quoteAssetAddress: address(stableUsd), baseAssetIsNumeraire: true}));
    oracleHub.addOracle(IOracleHubExtended.OracleInformation({oracleUnit: uint64(Constants.oracleStableEthToEthUnit), baseAssetNumeraire: 1, quoteAsset: "masETH", baseAsset: "ETH", oracleAddress: address(oracleStableUsdToUsd), quoteAssetAddress: address(stableEth), baseAssetIsNumeraire: true}));

  }

  function setAssetInformation() public onlyOwner {
    assetInfo memory asset;
    uint256[] memory emptyList = new uint256[](0);
    address[] memory genOracleArr = new address[](1);
    for (uint i; i < assets.length; ++i) {
      asset = assets[i];
      genOracleArr[0] = asset.oracleAddr;
      if (asset.decimals == 0) {
        floorERC721Registry.setAssetInformation(IErc721SubRegistry.AssetInformation({oracleAddresses: genOracleArr, idRangeStart:0, idRangeEnd:type(uint256).max, assetAddress: asset.assetAddr}), emptyList);
      }
      else {
        standardERC20Registry.setAssetInformation(IErc20SubRegistry.AssetInformation({oracleAddresses: genOracleArr, assetUnit: uint64(10**asset.decimals), assetAddress: asset.assetAddr}), emptyList);
        }
    }

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    address[] memory oracleStableUsdToUsdArr = new address[](1);    
    oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);

    address[] memory oracleStableEthToUsdArr = new address[](2);
    oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
    oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

    standardERC20Registry.setAssetInformation(IErc20SubRegistry.AssetInformation({oracleAddresses: oracleEthToUsdArr, assetUnit: uint64(10**Constants.ethDecimals), assetAddress: address(weth)}), emptyList);
    standardERC20Registry.setAssetInformation(IErc20SubRegistry.AssetInformation({oracleAddresses: oracleStableUsdToUsdArr, assetUnit: uint64(10**Constants.stableDecimals), assetAddress: address(stableUsd)}), emptyList);
    standardERC20Registry.setAssetInformation(IErc20SubRegistry.AssetInformation({oracleAddresses: oracleStableEthToUsdArr, assetUnit: uint64(10**Constants.stableEthDecimals), assetAddress: address(stableEth)}), emptyList);


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