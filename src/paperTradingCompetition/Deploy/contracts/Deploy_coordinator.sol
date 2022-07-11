/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
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
import "../../../utils/StringHelpers.sol";

interface IDeployerOne {
    function deployFact() external returns (address);

    function deployStable(
        string calldata,
        string calldata,
        uint8,
        address,
        address
    ) external returns (address);

    function deployOracle(
        uint8,
        string calldata,
        address
    ) external returns (address);

    function deployOracleStable(
        uint8,
        string calldata,
        address
    ) external returns (address);
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

    function deployMainReg(NumeraireInformation calldata)
        external
        returns (address);

    function deployLiquidator(address, address) external returns (address);

    function deployTokenShop(address) external returns (address);
}

interface IDeployerThree {
    function deployERC20(
        string calldata,
        string calldata,
        uint8,
        address
    ) external returns (address);

    function deployERC721(
        string calldata,
        string calldata,
        address
    ) external returns (address);

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

    function setNewVaultInfo(
        address,
        address,
        address,
        address
    ) external;

    function confirmNewVaultInfo() external;

    function setLiquidator(address) external;

    function createVault(uint256, uint256) external returns (address);

    function baseURI() external view returns (string memory);

    function liquidatorAddress() external view returns (address);

    function newVaultInfoSet() external view returns (bool);

    function currentVaultVersion() external view returns (uint256);

    function vaultDetails(uint256)
        external
        view
        returns (
            address,
            address,
            address,
            address
        );

    function numeraireToStable(uint256) external view returns (address);

    function numeraireCounter() external view returns (uint256);

    function transferOwnership(address) external;

    function setTokenShop(address) external;
}

interface IStablePaperTradingExtended is IStable {
    function setLiquidator(address) external;

    function liquidator() external view returns (address);

    function factory() external view returns (address);

    function setTokenShop(address) external;

    function tokenShop() external view returns (address);
}

interface IOraclePaperTradingExtended is IChainLinkData {
    function transmit(int256) external;

    struct OracleInformation {
        uint64 oracleUnit;
        uint8 baseAssetNumeraire;
        bool baseAssetIsNumeraire;
        string quoteAsset;
        string baseAsset;
        address oracleAddress;
        address quoteAssetAddress;
    }

    function transferOwnership(address) external;
}

interface IMainRegistryExtended is IMainRegistry {
    function addSubRegistry(address) external;

    function setFactory(address) external;

    function isSubRegistry(address) external view returns (bool);

    function numeraireCounter() external view returns (uint256);

    function transferOwnership(address) external;

    struct NumeraireInformation {
        uint64 numeraireToUsdOracleUnit;
        uint64 numeraireUnit;
        address assetAddress;
        address numeraireToUsdOracle;
        address stableAddress;
        string numeraireLabel;
    }

    function addNumeraire(NumeraireInformation calldata, uint256[] calldata)
        external;
}

interface ILiquidatorPaperTradingExtended is ILiquidator {
    function setFactory(address) external;

    function registryAddress() external view returns (address);

    function factoryAddress() external view returns (address);

    function stable() external view returns (address);

    function transferOwnership(address) external;
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

    function transferOwnership(address) external;
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
    function setAssetInformation(
        IErc721SubRegistry.AssetInformation calldata,
        uint256[] calldata
    ) external;

    function setAssetInformation(
        IErc20SubRegistry.AssetInformation calldata,
        uint256[] calldata
    ) external;

    function mainRegistry() external view returns (address);

    function oracleHub() external view returns (address);

    function transferOwnership(address) external;
}

interface IIRMExtended is IRM {
    function setBaseInterestRate(uint64) external;

    function transferOwnership(address) external;
}

interface ITokenShopExtended is ITokenShop {
    function mainRegistry() external view returns (address);

    function setFactory(address) external;

    function transferOwnership(address) external;
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

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleStableToUsdArr = new address[](1);

    address public owner;

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

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor(
        address _deployerOne,
        address _deployerTwo,
        address _deployerThree,
        address _deployerFour
    ) {
        owner = msg.sender;
        deployerOne = IDeployerOne(_deployerOne);
        deployerTwo = IDeployerTwo(_deployerTwo);
        deployerThree = IDeployerThree(_deployerThree);
        deployerFour = IDeployerFour(_deployerFour);
    }

    function createNewVaultThroughDeployer(address newVaultOwner)
        public
        onlyOwner
    {
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)",
                        block.timestamp,
                        block.number,
                        blockhash(block.number)
                    )
                )
            ),
            0
        );
        factory.safeTransferFrom(
            address(this),
            newVaultOwner,
            factory.vaultIndex(address(proxyAddr))
        );
    }

    function setOracleAnswer(address oracleAddr, uint256 amount)
        external
        onlyOwner
    {
        IOraclePaperTradingExtended(oracleAddr).transmit(int256(amount));
    }

    //1. start()
    //2. deployer.storeAssets()
    // [[8, 8, "2934300000000", "Mocked Wrapped BTC", "mwBTC", "BTC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "100000000", "Mocked USD Coin", "mUSDC", "USDC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1179", "Mocked SHIBA INU", "mSHIB", "SHIB", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6460430", "Mocked Matic Token", "mMATIC", "MATIC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "1872500", "Mocked Cronos Coin", "mCRO", "CRO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "567000000", "Mocked Uniswap", "mUNI", "UNI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "706000000", "Mocked ChainLink Token", "mLINK", "LINK", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2976000000", "Mocked FTX Token", "mFTT", "FTT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "765000000", "Mocked ApeCoin", "mAPE", "APE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "130000000", "Mocked The Sandbox", "mSAND", "SAND", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "103000000", "Mocked Decentraland", "mMANA", "MANA", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2107000000", "Mocked Axie Infinity", "mAXS", "AXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9992000000", "Mocked Aave", "mAAVE", "AAVE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "4447550", "Mocked Fantom", "mFTM", "FTM", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "1676000000", "Mocked KuCoin Token ", "mKCS", "KCS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "131568000000", "Mocked Maker", "mMKR", "MKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "100000000", "Mocked Dai", "mDAI", "DAI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1028000000", "Mocked Convex Finance", "mCVX", "CVX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "128000000", "Mocked Curve DAO Token", "mCRV", "CRV", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "5711080", "Mocked Loopring", "mLRC", "LRC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "3913420", "Mocked BAT", "mBAT", "BAT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "13226", "Mocked Amp", "mAMP", "AMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6943000000", "Mocked Compound", "mCOMP", "COMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9926070", "Mocked 1INCH Token", "m1INCH", "1INCH", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "21117000000", "Mocked Gnosis", "mGNO", "GNO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "257000000", "Mocked OMG Network", "mOMG", "OMG", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "138000000", "Mocked Bancor", "mBNT", "BNT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [4, 8, "7629100", "Mocked Celsius Network", "mCEL", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "392627", "Mocked Ankr Network", "mANKR", "ANKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "721000000", "Mocked Frax Share ", "mFXS", "FXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9487620", "Mocked Immutable X", "mIMX", "IMX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1238000000", "Mocked Ethereum Name Service ", "mENS", "ENS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "166000000", "Mocked SushiToken", "mSUSHI", "SUSHI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "206000000", "Mocked Mocked dYdX", "mDYDX", "DYDX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "186335", "Mocked CelerToken", "mCELR", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "48950000000000000000", "Mocked CRYPTOPUNKS", "mC", "PUNK", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "93990000000000000000", "Mocked BoredApeYachtClub", "mBAYC", "BAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "18850000000000000000", "Mocked MutantApeYachtClub", "mMAYC", "MAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "14400000000000000000", "Mocked CloneX", "mCloneX", "CloneX", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1100000000000000000", "Mocked Loot", "mLOOT", "LOOT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1630000000000000000", "Mocked Sandbox's LANDs", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "3490000000000000000", "Mocked Cool Cats", "mCOOL", "COOL", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12700000000000000000", "Mocked Azuki", "mAZUKI", "AZUKI", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12690000000000000000", "Mocked Doodles", "mDOODLE", "DOODLE", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "4600000000000000000", "Mocked Meebits", "mMEEBIT", "MEEBIT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2760000000000000000", "Mocked CyberKongz", "mKONGZ", "KONGZ", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "7200000000000000000", "Mocked BoredApeKennelClub", "mBAKC", "BAKC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2000000000000000000", "Mocked Decentraland LAND", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "380000000000000000", "Mocked Timeless", "mTMLS", "TMLS", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "10500000000000000000", "Mocked Treeverse", "mTRV", "TRV", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"]]
    //3  continue in order

    function start() public onlyOwner {
        factory = IFactoryPaperTradingExtended(deployerOne.deployFact());
        factory.setBaseURI("ipfs://");

        stableUsd = IStablePaperTradingExtended(
            deployerOne.deployStable(
                "Mocked Arcadia USD",
                "maUSD",
                uint8(Constants.stableDecimals),
                0x0000000000000000000000000000000000000000,
                address(factory)
            )
        );
        stableEth = IStablePaperTradingExtended(
            deployerOne.deployStable(
                "Mocked Arcadia ETH",
                "maETH",
                uint8(Constants.stableEthDecimals),
                0x0000000000000000000000000000000000000000,
                address(factory)
            )
        );

        oracleEthToUsd = IOraclePaperTradingExtended(
            deployerOne.deployOracle(
                uint8(Constants.oracleEthToUsdDecimals),
                "ETH / USD",
                address(stableEth)
            )
        );
        oracleEthToUsd.transmit(int256(rateEthToUsd));

        oracleStableUsdToUsd = IOraclePaperTradingExtended(
            deployerOne.deployOracleStable(
                uint8(Constants.oracleStableToUsdDecimals),
                "maUSD / USD",
                address(stableUsd)
            )
        );
        oracleStableEthToEth = IOraclePaperTradingExtended(
            deployerOne.deployOracleStable(
                uint8(Constants.oracleStableEthToEthUnit),
                "maETH / ETH",
                address(stableEth)
            )
        );

        mainRegistry = IMainRegistryExtended(
            deployerTwo.deployMainReg(
                IDeployerTwo.NumeraireInformation({
                    numeraireToUsdOracleUnit: 0,
                    assetAddress: 0x0000000000000000000000000000000000000000,
                    numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                    stableAddress: address(stableUsd),
                    numeraireLabel: "USD",
                    numeraireUnit: 1
                })
            )
        );

        liquidator = ILiquidatorPaperTradingExtended(
            deployerTwo.deployLiquidator(
                address(factory),
                address(mainRegistry)
            )
        );
        stableUsd.setLiquidator(address(liquidator));
        stableEth.setLiquidator(address(liquidator));

        tokenShop = ITokenShopExtended(
            deployerTwo.deployTokenShop(address(mainRegistry))
        );
        tokenShop.setFactory(address(factory));
        weth = IERC20PaperTrading(
            deployerThree.deployERC20(
                "Mocked ETH",
                "mETH",
                uint8(Constants.ethDecimals),
                address(tokenShop)
            )
        );

        stableUsd.setTokenShop(address(tokenShop));
        stableEth.setTokenShop(address(tokenShop));

        oracleHub = IOracleHubExtended(deployerThree.deployOracHub());

        standardERC20Registry = IRegistryExtended(
            deployerThree.deployERC20SubReg(
                address(mainRegistry),
                address(oracleHub)
            )
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));

        floorERC721Registry = IRegistryExtended(
            deployerThree.deployERC721SubReg(
                address(mainRegistry),
                address(oracleHub)
            )
        );
        mainRegistry.addSubRegistry(address(floorERC721Registry));

        interestRateModule = IIRMExtended(deployerFour.deployIRM());
        interestRateModule.setBaseInterestRate(5 * 10**16);

        vault = IVaultPaperTrading(deployerFour.deployVaultLogic());
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factory.confirmNewVaultInfo();
        factory.setLiquidator(address(liquidator));
        factory.setTokenShop(address(tokenShop));
        liquidator.setFactory(address(factory));
        mainRegistry.setFactory(address(factory));
    }

    // [[8, 8, "2934300000000", "Mocked Wrapped BTC", "mwBTC", "BTC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "100000000", "Mocked USD Coin", "mUSDC", "USDC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1179", "Mocked SHIBA INU", "mSHIB", "SHIB", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6460430", "Mocked Matic Token", "mMATIC", "MATIC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "1872500", "Mocked Cronos Coin", "mCRO", "CRO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "567000000", "Mocked Uniswap", "mUNI", "UNI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "706000000", "Mocked ChainLink Token", "mLINK", "LINK", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2976000000", "Mocked FTX Token", "mFTT", "FTT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "765000000", "Mocked ApeCoin", "mAPE", "APE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [8, 8, "130000000", "Mocked The Sandbox", "mSAND", "SAND", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "103000000", "Mocked Decentraland", "mMANA", "MANA", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "2107000000", "Mocked Axie Infinity", "mAXS", "AXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9992000000", "Mocked Aave", "mAAVE", "AAVE", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "4447550", "Mocked Fantom", "mFTM", "FTM", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [6, 8, "1676000000", "Mocked KuCoin Token ", "mKCS", "KCS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "131568000000", "Mocked Maker", "mMKR", "MKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "100000000", "Mocked Dai", "mDAI", "DAI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1028000000", "Mocked Convex Finance", "mCVX", "CVX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "128000000", "Mocked Curve DAO Token", "mCRV", "CRV", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "5711080", "Mocked Loopring", "mLRC", "LRC", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "3913420", "Mocked BAT", "mBAT", "BAT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "13226", "Mocked Amp", "mAMP", "AMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "6943000000", "Mocked Compound", "mCOMP", "COMP", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9926070", "Mocked 1INCH Token", "m1INCH", "1INCH", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "21117000000", "Mocked Gnosis", "mGNO", "GNO", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "257000000", "Mocked OMG Network", "mOMG", "OMG", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "138000000", "Mocked Bancor", "mBNT", "BNT", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [4, 8, "7629100", "Mocked Celsius Network", "mCEL", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "392627", "Mocked Ankr Network", "mANKR", "ANKR", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "721000000", "Mocked Frax Share ", "mFXS", "FXS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "9487620", "Mocked Immutable X", "mIMX", "IMX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "1238000000", "Mocked Ethereum Name Service ", "mENS", "ENS", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "166000000", "Mocked SushiToken", "mSUSHI", "SUSHI", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "206000000", "Mocked Mocked dYdX", "mDYDX", "DYDX", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [18, 8, "186335", "Mocked CelerToken", "mCELR", "CEL", "USD", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "48950000000000000000", "Mocked CRYPTOPUNKS", "mC", "PUNK", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "93990000000000000000", "Mocked BoredApeYachtClub", "mBAYC", "BAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "18850000000000000000", "Mocked MutantApeYachtClub", "mMAYC", "MAYC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "14400000000000000000", "Mocked CloneX", "mCloneX", "CloneX", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1100000000000000000", "Mocked Loot", "mLOOT", "LOOT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "1630000000000000000", "Mocked Sandbox's LANDs", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "3490000000000000000", "Mocked Cool Cats", "mCOOL", "COOL", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12700000000000000000", "Mocked Azuki", "mAZUKI", "AZUKI", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "12690000000000000000", "Mocked Doodles", "mDOODLE", "DOODLE", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "4600000000000000000", "Mocked Meebits", "mMEEBIT", "MEEBIT", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2760000000000000000", "Mocked CyberKongz", "mKONGZ", "KONGZ", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "7200000000000000000", "Mocked BoredApeKennelClub", "mBAKC", "BAKC", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "2000000000000000000", "Mocked Decentraland LAND", "mLAND", "LAND", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "380000000000000000", "Mocked Timeless", "mTMLS", "TMLS", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], [0, 18, "10500000000000000000", "Mocked Treeverse", "mTRV", "TRV", "ETH", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"]]
    function storeAssets(assetInfo[] calldata _assets) public onlyOwner {
        assets.push(
            assetInfo({
                desc: "Mocked Wrapped Ether",
                symbol: "mwETH",
                decimals: 18,
                rate: uint128(rateEthToUsd),
                oracleDecimals: 8,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddr: address(oracleEthToUsd),
                assetAddr: address(weth)
            })
        );

        for (uint256 i; i < _assets.length; ++i) {
            assets.push(_assets[i]);
        }
    }

    function deployERC20Contracts() public onlyOwner {
        address newContr;
        assetInfo memory asset;
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            if (asset.decimals == 0) {} else {
                if (asset.assetAddr == address(0)) {
                    newContr = deployerThree.deployERC20(
                        asset.desc,
                        asset.symbol,
                        asset.decimals,
                        address(tokenShop)
                    );
                    assets[i].assetAddr = newContr;
                }
            }
        }
    }

    function deployERC721Contracts() public onlyOwner {
        address newContr;
        assetInfo memory asset;
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            if (asset.decimals == 0) {
                newContr = deployerThree.deployERC721(
                    asset.desc,
                    asset.symbol,
                    address(tokenShop)
                );
                assets[i].assetAddr = newContr;
            } else {}
        }
    }

    function deployOracles() public onlyOwner {
        address newContr;
        assetInfo memory asset;
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            if (!StringHelpers.compareStrings(asset.symbol, "mwETH")) {
                newContr = deployerOne.deployOracle(
                    asset.oracleDecimals,
                    string(abi.encodePacked(asset.quoteAsset, " / USD")),
                    asset.assetAddr
                );
                assets[i].oracleAddr = newContr;
            }
        }

        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addNumeraire(
            IMainRegistryExtended.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(weth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: address(stableEth),
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
    }

    function setOracleAnswers() public onlyOwner {
        assetInfo memory asset;
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            IOraclePaperTradingExtended(asset.oracleAddr).transmit(
                int256(uint256(asset.rate))
            );
        }
    }

    function addOracles() public onlyOwner {
        assetInfo memory asset;
        uint8 baseAssetNum;
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            if (StringHelpers.compareStrings(asset.baseAsset, "ETH")) {
                baseAssetNum = 1;
            } else {
                baseAssetNum = 0;
            }
            oracleHub.addOracle(
                IOracleHubExtended.OracleInformation({
                    oracleUnit: uint64(10**asset.oracleDecimals),
                    baseAssetNumeraire: baseAssetNum,
                    quoteAsset: asset.quoteAsset,
                    baseAsset: asset.baseAsset,
                    oracleAddress: asset.oracleAddr,
                    quoteAssetAddress: asset.assetAddr,
                    baseAssetIsNumeraire: true
                })
            );
        }

        oracleHub.addOracle(
            IOracleHubExtended.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "maUSD",
                baseAsset: "USD",
                oracleAddress: address(oracleStableUsdToUsd),
                quoteAssetAddress: address(stableUsd),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            IOracleHubExtended.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableEthToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "maETH",
                baseAsset: "ETH",
                oracleAddress: address(oracleStableEthToEth),
                quoteAssetAddress: address(stableEth),
                baseAssetIsNumeraire: true
            })
        );
    }

    function setAssetInformation() public onlyOwner {
        assetInfo memory asset;
        uint256[] memory emptyList = new uint256[](0);
        address[] memory genOracleArr1 = new address[](1);
        address[] memory genOracleArr2 = new address[](2);
        for (uint256 i; i < assets.length; ++i) {
            asset = assets[i];
            if (StringHelpers.compareStrings(asset.baseAsset, "ETH")) {
                genOracleArr2[0] = asset.oracleAddr;
                genOracleArr2[1] = address(oracleEthToUsd);

                if (asset.decimals == 0) {
                    floorERC721Registry.setAssetInformation(
                        IErc721SubRegistry.AssetInformation({
                            oracleAddresses: genOracleArr2,
                            idRangeStart: 0,
                            idRangeEnd: type(uint256).max,
                            assetAddress: asset.assetAddr
                        }),
                        emptyList
                    );
                } else {
                    standardERC20Registry.setAssetInformation(
                        IErc20SubRegistry.AssetInformation({
                            oracleAddresses: genOracleArr2,
                            assetUnit: uint64(10**asset.decimals),
                            assetAddress: asset.assetAddr
                        }),
                        emptyList
                    );
                }
            } else {
                genOracleArr1[0] = asset.oracleAddr;

                if (asset.decimals == 0) {
                    floorERC721Registry.setAssetInformation(
                        IErc721SubRegistry.AssetInformation({
                            oracleAddresses: genOracleArr1,
                            idRangeStart: 0,
                            idRangeEnd: type(uint256).max,
                            assetAddress: asset.assetAddr
                        }),
                        emptyList
                    );
                } else {
                    standardERC20Registry.setAssetInformation(
                        IErc20SubRegistry.AssetInformation({
                            oracleAddresses: genOracleArr1,
                            assetUnit: uint64(10**asset.decimals),
                            assetAddress: asset.assetAddr
                        }),
                        emptyList
                    );
                }
            }
        }

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        address[] memory oracleStableUsdToUsdArr = new address[](1);
        oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);

        address[] memory oracleStableEthToUsdArr = new address[](2);
        oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
        oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

        standardERC20Registry.setAssetInformation(
            IErc20SubRegistry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(weth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            IErc20SubRegistry.AssetInformation({
                oracleAddresses: oracleStableUsdToUsdArr,
                assetUnit: uint64(10**Constants.stableDecimals),
                assetAddress: address(stableUsd)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            IErc20SubRegistry.AssetInformation({
                oracleAddresses: oracleStableEthToUsdArr,
                assetUnit: uint64(10**Constants.stableEthDecimals),
                assetAddress: address(stableEth)
            }),
            emptyList
        );
    }

    function transferOwnership() public onlyOwner {
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
        require(
            mainRegistry.isSubRegistry(address(standardERC20Registry)),
            "MR: ERC20SR not set"
        );
        require(
            mainRegistry.isSubRegistry(address(floorERC721Registry)),
            "MR: ERC721SR not set"
        );
        require(
            mainRegistry.factoryAddress() == address(factory),
            "MR: fact not set"
        );

        uint64 numeraireToUsdOracleUnit;
        uint64 numeraireUnit;
        address assetAddress;
        address numeraireToUsdOracle;
        address stableAddress;
        string memory numeraireLabel;

        uint256 numCounter = mainRegistry.numeraireCounter();
        require(numCounter > 0);
        for (uint256 i; i < numCounter; ++i) {
            (
                numeraireToUsdOracleUnit,
                numeraireUnit,
                assetAddress,
                numeraireToUsdOracle,
                stableAddress,
                numeraireLabel
            ) = mainRegistry.numeraireToInformation(0);
            require(
                numeraireToUsdOracleUnit != 0 &&
                    numeraireUnit != 0 &&
                    assetAddress != address(0) &&
                    numeraireToUsdOracle != address(0) &&
                    stableAddress != address(0) &&
                    bytes(numeraireLabel).length != 0,
                "MR: num 0 not set"
            );
        }

        return true;
    }

    function checkSubregs() public view returns (bool) {
        require(
            standardERC20Registry.mainRegistry() == address(mainRegistry),
            "ERC20SR: mainreg not set"
        );
        require(
            floorERC721Registry.mainRegistry() == address(mainRegistry),
            "ERC721SR: mainreg not set"
        );
        require(
            standardERC20Registry.oracleHub() == address(oracleHub),
            "ERC20SR: OH not set"
        );
        require(
            floorERC721Registry.oracleHub() == address(oracleHub),
            "ERC721SR: OH not set"
        );

        return true;
    }

    function checkLiquidator() public view returns (bool) {
        require(
            liquidator.registryAddress() == address(mainRegistry),
            "Liq: mainreg not set"
        );
        require(
            liquidator.factoryAddress() == address(factory),
            "Liq: fact not set"
        );

        return true;
    }

    function checkTokenShop() public view returns (bool) {
        require(
            tokenShop.mainRegistry() == address(mainRegistry),
            "TokenShop: mainreg not set"
        );

        return true;
    }

    function checkStables() public view returns (bool) {
        require(
            stableUsd.liquidator() == address(liquidator),
            "StableUSD: liq not set"
        );
        require(
            stableUsd.factory() == address(factory),
            "StableUSD: fact not set"
        );
        require(
            stableEth.liquidator() == address(liquidator),
            "StableETH: liq not set"
        );
        require(
            stableEth.factory() == address(factory),
            "StableETH: fact not set"
        );
        require(
            stableUsd.tokenShop() == address(tokenShop),
            "StableUSD: tokensh not set"
        );
        require(
            stableEth.tokenShop() == address(tokenShop),
            "StableETH: tokensh not set"
        );

        return true;
    }

    function checkFactory() public view returns (bool) {
        require(bytes(factory.baseURI()).length != 0, "FTRY: baseURI not set");
        uint256 numCountFact = factory.numeraireCounter();
        require(
            numCountFact == mainRegistry.numeraireCounter(),
            "FTRY: numCountFact != numCountMR"
        );
        require(
            factory.liquidatorAddress() != address(0),
            "FTRY: LiqAddr not set"
        );
        require(
            factory.newVaultInfoSet() == false,
            "FTRY: newVaultInfo still set"
        );
        require(
            factory.getCurrentRegistry() == address(mainRegistry),
            "FTRY: mainreg not set"
        );
        (, address factLogic, address factStake, address factIRM) = factory
            .vaultDetails(factory.currentVaultVersion());
        require(factLogic == address(vault), "FTRY: vaultLogic not set");
        require(
            factStake == address(stakeContract),
            "FTRY: stakeContr not set"
        );
        require(factIRM == address(interestRateModule), "FTRY: IRM not set");
        for (uint256 i; i < numCountFact; ++i) {
            require(
                factory.numeraireToStable(i) != address(0),
                string(
                    abi.encodePacked(
                        "FTRY: numToStable not set for",
                        Strings.toString(i)
                    )
                )
            );
        }

        return true;
    }

    error AddressNotInitialised();

    function checkAddressesInit() public view returns (bool) {
        require(owner != address(0), "AddrCheck: owner not set");
        require(address(factory) != address(0), "AddrCheck: factory not set");
        require(address(vault) != address(0), "AddrCheck: vault not set");
        require(
            address(oracleHub) != address(0),
            "AddrCheck: oracleHub not set"
        );
        require(
            address(mainRegistry) != address(0),
            "AddrCheck: mainRegistry not set"
        );
        require(
            address(standardERC20Registry) != address(0),
            "AddrCheck: standardERC20Registry not set"
        );
        require(
            address(floorERC721Registry) != address(0),
            "AddrCheck: floorERC721Registry not set"
        );
        require(
            address(interestRateModule) != address(0),
            "AddrCheck: interestRateModule not set"
        );
        require(
            address(stableUsd) != address(0),
            "AddrCheck: stableUsd not set"
        );
        require(
            address(stableEth) != address(0),
            "AddrCheck: stableEth not set"
        );
        require(
            address(oracleStableUsdToUsd) != address(0),
            "AddrCheck: oracleStableUsdToUsd not set"
        );
        require(
            address(oracleStableEthToEth) != address(0),
            "AddrCheck: oracleStableEthToEth not set"
        );
        require(
            address(liquidator) != address(0),
            "AddrCheck: liquidator not set"
        );
        require(
            address(tokenShop) != address(0),
            "AddrCheck: tokenShop not set"
        );
        require(address(weth) != address(0), "AddrCheck: weth not set");
        require(
            address(oracleEthToUsd) != address(0),
            "AddrCheck: oracleEthToUsd not set"
        );

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

    function returnAllAddresses()
        public
        view
        returns (returnAddrs memory addrs)
    {
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

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
