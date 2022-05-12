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

interface IFactoryPaperTradingExtended is IFactoryPaperTrading {
  function setBaseURI(string memory) external;
  function setNewVaultInfo(address, address, address, address) external;
  function confirmNewVaultInfo() external;
  function setLiquidator(address) external;
}
interface IFactDeployer {
  function deploy() external returns (IFactoryPaperTradingExtended);
}

interface IStablePaperTradingExtended is IStable {
  function setLiquidator(address) external;
}
interface IStableDeployer {
  function deploy(string calldata, string calldata, uint8, address, address) external returns (IStablePaperTradingExtended);
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
interface IOracleDeployer {
  function deploy(uint8, string calldata) external returns (IOraclePaperTradingExtended);
  function deployStable(uint8, string calldata) external returns (IOraclePaperTradingExtended);
}

interface IMainRegistryExtended is IMainRegistry {
  function addSubRegistry(address) external;
  function setFactory(address) external;

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

interface IMainRegDeployer {
  struct NumeraireInformation {
    uint64 numeraireToUsdOracleUnit;
    uint64 numeraireUnit;
    address assetAddress;
    address numeraireToUsdOracle;
    address stableAddress;
    string numeraireLabel;
  }

  function deploy(NumeraireInformation calldata) external returns (IMainRegistryExtended);
}

interface ILiquidatorPaperTradingExtended is ILiquidator {
  function setFactory(address) external;
}
interface ILiquidatorDeployer {
  function deploy(address, address, address) external returns (ILiquidatorPaperTradingExtended);
}

interface ITokenShopDeployer {
  function deploy(address) external returns (ITokenShop);
}

interface IErc20Deployer {
  function deploy(string calldata, string calldata, uint8, address) external returns (IERC20PaperTrading);
}

interface IErc721Deployer {
  function deploy(string calldata, string calldata, address) external returns (IERC721PaperTrading);
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
interface IOracleHubDeployer {
  function deploy() external returns (IOracleHubExtended);
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
}
interface IRegistryDeployer {
  function deployERC20(address, address) external returns (IRegistryExtended);
  function deployERC721(address, address) external returns (IRegistryExtended);
}

interface IIRMExtended is IRM {
  function setBaseInterestRate(uint256) external;
}
interface IIrmDeployer {
  function deploy() external returns (IIRMExtended);
}

interface IVaultLogicDeployer {
  function deploy() external returns (IVaultPaperTrading);
}



contract DeployCoordinator {

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
  ITokenShop public tokenShop;

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

  IFactDeployer public factDeployer;
  IStableDeployer public stableDeployer;
  IOracleDeployer public oracleDeployer;
  IOracleDeployer public stableOracleDeployer;
  IMainRegDeployer public mainRegDeployer;
  ILiquidatorDeployer public liquidatorDeployer;
  ITokenShopDeployer public tokenShopDeployer;
  IErc20Deployer public erc20Deployer;
  IErc721Deployer public erc721Deployer;
  IOracleHubDeployer public oracleHubDeployer;
  IRegistryDeployer public registryDeployer;
  IIrmDeployer public irmDeployer;
  IVaultLogicDeployer public vaultLogicDeployer;
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

  constructor(address _factDeployer) {
    owner = msg.sender;
    factDeployer = IFactDeployer(_factDeployer);
  }
  

  function start() public {
    factory = factDeployer.deploy();
    factory.setBaseURI("ipfs://");

    stableUsd = stableDeployer.deploy("Arcadia USD Stable Mock", "masUSD", uint8(Constants.stableDecimals), 0x0000000000000000000000000000000000000000, address(factory));
    stableEth = stableDeployer.deploy("Arcadia ETH Stable Mock", "masETH", uint8(Constants.stableEthDecimals), 0x0000000000000000000000000000000000000000, address(factory));

    oracleEthToUsd = oracleDeployer.deploy(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD");
    oracleEthToUsd.setAnswer(int256(rateEthToUsd));

    oracleStableUsdToUsd = stableOracleDeployer.deployStable(uint8(Constants.oracleStableToUsdDecimals), "masUSD / USD");
    oracleStableEthToEth = stableOracleDeployer.deployStable(uint8(Constants.oracleStableEthToEthUnit), "masEth / Eth");

    mainRegistry = mainRegDeployer.deploy(IMainRegDeployer.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, stableAddress:address(stableUsd), numeraireLabel:'USD', numeraireUnit:1}));

    liquidator = liquidatorDeployer.deploy(address(factory), address(mainRegistry), address(stableUsd));
    stableUsd.setLiquidator(address(liquidator));
    stableEth.setLiquidator(address(liquidator));

    tokenShop = tokenShopDeployer.deploy(address(mainRegistry));
    weth = erc20Deployer.deploy("ETH Mock", "mETH", uint8(Constants.ethDecimals), address(tokenShop));

    oracleHub = oracleHubDeployer.deploy();

    standardERC20Registry = registryDeployer.deployERC20(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(standardERC20Registry));

    floorERC721Registry = registryDeployer.deployERC721(address(mainRegistry), address(oracleHub));
    mainRegistry.addSubRegistry(address(floorERC721Registry));

    oracleEthToUsdArr[0] = address(oracleEthToUsd);
    oracleStableToUsdArr[0] = address(oracleStableUsdToUsd);

    interestRateModule = irmDeployer.deploy();
    interestRateModule.setBaseInterestRate(5 * 10 **16);

    vault = vaultLogicDeployer.deploy();
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
          newContr = address(erc20Deployer.deploy(asset.desc, asset.symbol, asset.decimals, address(tokenShop)));
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
        newContr = address(erc721Deployer.deploy(asset.desc, asset.symbol, address(tokenShop)));
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
      newContr = address(oracleDeployer.deploy(asset.oracleDecimals, string(abi.encodePacked(asset.quoteAsset, " / USD"))));
      assets[i].oracleAddr = newContr;
    }

    uint256[] memory emptyList = new uint256[](0);
    mainRegistry.addNumeraire(IMainRegistryExtended.NumeraireInformation({numeraireToUsdOracleUnit:uint64(10**Constants.oracleEthToUsdDecimals), assetAddress:address(weth), numeraireToUsdOracle:address(oracleEthToUsd), stableAddress:address(stableUsd), numeraireLabel:'ETH', numeraireUnit:uint64(10**Constants.ethDecimals)}), emptyList);

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

    oracleHub.addOracle(IOracleHubExtended.OracleInformation({oracleUnit: uint64(10**18), baseAssetNumeraire: 0, quoteAsset: "STABLE", baseAsset: "USD", oracleAddress: address(oracleStableUsdToUsd), quoteAssetAddress: address(0), baseAssetIsNumeraire: true}));

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

  }

}