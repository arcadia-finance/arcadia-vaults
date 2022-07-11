/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../paperTradingCompetition/Deploy/contracts/Deploy_coordinator.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_one.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_two.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_three.sol";
import "../../paperTradingCompetition/Deploy/contracts/Deploy_four.sol";
import "src/script/paperTradingCompetition/helper.sol";

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/Test.sol";
import "../../utils/StringHelpers.sol";

interface IVaultValue {
    function getValue(uint8) external view returns (uint256);
}

interface Itest {
    function tokenShop() external view returns (address);

    function _tokenShop() external view returns (address);

    function swapNumeraireForExactTokens(
        DeployCoordTest.TokenInfo calldata,
        uint256
    ) external;

    function assets(uint256)
        external
        view
        returns (DeployCoordinator.assetInfo memory);
}

contract DeployCoordTest is Test {
    using stdStorage for StdStorage;

    DeployCoordinator public deployCoordinator;
    DeployContractsOne public deployContractsOne;
    DeployContractsTwo public deployContractsTwo;
    DeployContractsThree public deployContractsThree;
    DeployContractsFour public deployContractsFour;

    DeployCoordinator.assetInfo[] public assets;

    HelperContract public helper;
    constructor() { }

    function testDeployAll() public {
        deployContractsOne = new DeployContractsOne();
        deployContractsTwo = new DeployContractsTwo();
        deployContractsThree = new DeployContractsThree();
        deployContractsFour = new DeployContractsFour();

        deployCoordinator = new DeployCoordinator(
            address(deployContractsOne),
            address(deployContractsTwo),
            address(deployContractsThree),
            address(deployContractsFour)
        );

        deployCoordinator.start();

        //address oracleEthToUsd = address(deployCoordinator.oracleEthToUsd());
        //address weth = address(deployCoordinator.weth());

        //assets.push(DeployCoordinator.assetInfo({desc: "Wrapped Ether - Mock", symbol: "mwETH", decimals: uint8(Constants.ethDecimals), rate: 300000000000, oracleDecimals: uint8(Constants.oracleEthToUsdDecimals), quoteAsset: "ETH", baseAsset: "USD", oracleAddr: oracleEthToUsd, assetAddr: weth}));

        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Wrapped BTC",
                symbol: "mwBTC",
                decimals: 8,
                rate: 2934300000000,
                oracleDecimals: 8,
                quoteAsset: "BTC",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked USD Coin",
                symbol: "mUSDC",
                decimals: 6,
                rate: 100000000,
                oracleDecimals: 8,
                quoteAsset: "USDC",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked SHIBA INU",
                symbol: "mSHIB",
                decimals: 18,
                rate: 1179,
                oracleDecimals: 8,
                quoteAsset: "SHIB",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Matic Token",
                symbol: "mMATIC",
                decimals: 18,
                rate: 6460430,
                oracleDecimals: 8,
                quoteAsset: "MATIC",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Cronos Coin",
                symbol: "mCRO",
                decimals: 8,
                rate: 1872500,
                oracleDecimals: 8,
                quoteAsset: "CRO",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Uniswap",
                symbol: "mUNI",
                decimals: 18,
                rate: 567000000,
                oracleDecimals: 8,
                quoteAsset: "UNI",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked ChainLink Token",
                symbol: "mLINK",
                decimals: 18,
                rate: 706000000,
                oracleDecimals: 8,
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked FTX Token",
                symbol: "mFTT",
                decimals: 18,
                rate: 2976000000,
                oracleDecimals: 8,
                quoteAsset: "FTT",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked ApeCoin",
                symbol: "mAPE",
                decimals: 18,
                rate: 765000000,
                oracleDecimals: 8,
                quoteAsset: "APE",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked The Sandbox",
                symbol: "mSAND",
                decimals: 8,
                rate: 130000000,
                oracleDecimals: 8,
                quoteAsset: "SAND",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Decentraland",
                symbol: "mMANA",
                decimals: 18,
                rate: 103000000,
                oracleDecimals: 8,
                quoteAsset: "MANA",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Axie Infinity",
                symbol: "mAXS",
                decimals: 18,
                rate: 2107000000,
                oracleDecimals: 8,
                quoteAsset: "AXS",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Aave",
                symbol: "mAAVE",
                decimals: 18,
                rate: 9992000000,
                oracleDecimals: 8,
                quoteAsset: "AAVE",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Fantom",
                symbol: "mFTM",
                decimals: 18,
                rate: 4447550,
                oracleDecimals: 8,
                quoteAsset: "FTM",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked KuCoin Token ",
                symbol: "mKCS",
                decimals: 6,
                rate: 1676000000,
                oracleDecimals: 8,
                quoteAsset: "KCS",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Maker",
                symbol: "mMKR",
                decimals: 18,
                rate: 131568000000,
                oracleDecimals: 8,
                quoteAsset: "MKR",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Dai",
                symbol: "mDAI",
                decimals: 18,
                rate: 100000000,
                oracleDecimals: 8,
                quoteAsset: "DAI",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Convex Finance",
                symbol: "mCVX",
                decimals: 18,
                rate: 1028000000,
                oracleDecimals: 8,
                quoteAsset: "CVX",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Curve DAO Token",
                symbol: "mCRV",
                decimals: 18,
                rate: 128000000,
                oracleDecimals: 8,
                quoteAsset: "CRV",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Loopring",
                symbol: "mLRC",
                decimals: 18,
                rate: 5711080,
                oracleDecimals: 8,
                quoteAsset: "LRC",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked BAT",
                symbol: "mBAT",
                decimals: 18,
                rate: 3913420,
                oracleDecimals: 8,
                quoteAsset: "BAT",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Amp",
                symbol: "mAMP",
                decimals: 18,
                rate: 13226,
                oracleDecimals: 8,
                quoteAsset: "AMP",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Compound",
                symbol: "mCOMP",
                decimals: 18,
                rate: 6943000000,
                oracleDecimals: 8,
                quoteAsset: "COMP",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked 1INCH Token",
                symbol: "m1INCH",
                decimals: 18,
                rate: 9926070,
                oracleDecimals: 8,
                quoteAsset: "1INCH",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Gnosis",
                symbol: "mGNO",
                decimals: 18,
                rate: 21117000000,
                oracleDecimals: 8,
                quoteAsset: "GNO",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked OMG Network",
                symbol: "mOMG",
                decimals: 18,
                rate: 257000000,
                oracleDecimals: 8,
                quoteAsset: "OMG",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Bancor",
                symbol: "mBNT",
                decimals: 18,
                rate: 138000000,
                oracleDecimals: 8,
                quoteAsset: "BNT",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Celsius Network",
                symbol: "mCEL",
                decimals: 4,
                rate: 7629100,
                oracleDecimals: 8,
                quoteAsset: "CEL",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Ankr Network",
                symbol: "mANKR",
                decimals: 18,
                rate: 392627,
                oracleDecimals: 8,
                quoteAsset: "ANKR",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Frax Share ",
                symbol: "mFXS",
                decimals: 18,
                rate: 721000000,
                oracleDecimals: 8,
                quoteAsset: "FXS",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Immutable X",
                symbol: "mIMX",
                decimals: 18,
                rate: 9487620,
                oracleDecimals: 8,
                quoteAsset: "IMX",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Ethereum Name Service ",
                symbol: "mENS",
                decimals: 18,
                rate: 1238000000,
                oracleDecimals: 8,
                quoteAsset: "ENS",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked SushiToken",
                symbol: "mSUSHI",
                decimals: 18,
                rate: 166000000,
                oracleDecimals: 8,
                quoteAsset: "SUSHI",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Mocked dYdX",
                symbol: "mDYDX",
                decimals: 18,
                rate: 206000000,
                oracleDecimals: 8,
                quoteAsset: "DYDX",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked CelerToken",
                symbol: "mCELR",
                decimals: 18,
                rate: 186335,
                oracleDecimals: 8,
                quoteAsset: "CEL",
                baseAsset: "USD",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );

        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked CRYPTOPUNKS",
                symbol: "mC",
                decimals: 0,
                rate: 48950000000000000000,
                oracleDecimals: 18,
                quoteAsset: "PUNK",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked BoredApeYachtClub",
                symbol: "mBAYC",
                decimals: 0,
                rate: 93990000000000000000,
                oracleDecimals: 18,
                quoteAsset: "BAYC",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked MutantApeYachtClub",
                symbol: "mMAYC",
                decimals: 0,
                rate: 18850000000000000000,
                oracleDecimals: 18,
                quoteAsset: "MAYC",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked CloneX",
                symbol: "mCloneX",
                decimals: 0,
                rate: 14400000000000000000,
                oracleDecimals: 18,
                quoteAsset: "CloneX",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Loot",
                symbol: "mLOOT",
                decimals: 0,
                rate: 1100000000000000000,
                oracleDecimals: 18,
                quoteAsset: "LOOT",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Sandbox's LANDs",
                symbol: "mLAND",
                decimals: 0,
                rate: 1630000000000000000,
                oracleDecimals: 18,
                quoteAsset: "LAND",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Cool Cats",
                symbol: "mCOOL",
                decimals: 0,
                rate: 3490000000000000000,
                oracleDecimals: 18,
                quoteAsset: "COOL",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Azuki",
                symbol: "mAZUKI",
                decimals: 0,
                rate: 12700000000000000000,
                oracleDecimals: 18,
                quoteAsset: "AZUKI",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Doodles",
                symbol: "mDOODLE",
                decimals: 0,
                rate: 12690000000000000000,
                oracleDecimals: 18,
                quoteAsset: "DOODLE",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Meebits",
                symbol: "mMEEBIT",
                decimals: 0,
                rate: 4600000000000000000,
                oracleDecimals: 18,
                quoteAsset: "MEEBIT",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked CyberKongz",
                symbol: "mKONGZ",
                decimals: 0,
                rate: 2760000000000000000,
                oracleDecimals: 18,
                quoteAsset: "KONGZ",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked BoredApeKennelClub",
                symbol: "mBAKC",
                decimals: 0,
                rate: 7200000000000000000,
                oracleDecimals: 18,
                quoteAsset: "BAKC",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Decentraland LAND",
                symbol: "mLAND",
                decimals: 0,
                rate: 2000000000000000000,
                oracleDecimals: 18,
                quoteAsset: "LAND",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Timeless",
                symbol: "mTMLS",
                decimals: 0,
                rate: 380000000000000000,
                oracleDecimals: 18,
                quoteAsset: "TMLS",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );
        assets.push(
            DeployCoordinator.assetInfo({
                desc: "Mocked Treeverse",
                symbol: "mTRV",
                decimals: 0,
                rate: 10500000000000000000,
                oracleDecimals: 18,
                quoteAsset: "TRV",
                baseAsset: "ETH",
                oracleAddr: address(0),
                assetAddr: address(0)
            })
        );

        deployCoordinator.storeAssets(assets);

        deployCoordinator.deployERC20Contracts();
        deployCoordinator.deployERC721Contracts();
        deployCoordinator.deployOracles();
        deployCoordinator.setOracleAnswers();
        deployCoordinator.addOracles();
        emit log_named_address(
            "OracleEThToUsd",
            address(deployCoordinator.oracleEthToUsd())
        );
        checkOracle();
        deployCoordinator.setAssetInformation();

        deployCoordinator.verifyView();

        deployCoordinator.createNewVaultThroughDeployer(address(this));
        //deployCoordinator.transferOwnership();

        vm.startPrank(address(3));
        address firstVault = IFactoryPaperTradingExtended(
            deployCoordinator.factory()
        ).createVault(125498456465, 0);
        address secondVault = IFactoryPaperTradingExtended(
            deployCoordinator.factory()
        ).createVault(125498456465545885545, 1);
        vm.stopPrank();

        address[] memory tokenAddresses_l = new address[](1);
        DeployCoordinator.assetInfo memory r = Itest(address(deployCoordinator))
            .assets(39);

        //deployCoordinator.setOracleAnswer(r.oracleAddr, 1 * 10**8);
        emit log_named_bytes("name", bytes(r.symbol));
        tokenAddresses_l[0] = r.assetAddr;
        uint256[] memory tokenIds_l = new uint256[](1);
        tokenIds_l[0] = 1;
        uint256[] memory tokenAmounts_l = new uint256[](1);
        tokenAmounts_l[0] = 1;
        uint256[] memory tokenTypes_l = new uint256[](1);
        tokenTypes_l[0] = 1;

        emit log_named_address(
            "tokenShopVault",
            Itest(firstVault)._tokenShop()
        );
        emit log_named_address(
            "tokenShop",
            Itest(address(deployCoordinator)).tokenShop()
        );

        emit log_named_address("tokenShopVault", Itest(firstVault)._tokenShop());
        emit log_named_address("tokenShop", Itest(address(deployCoordinator)).tokenShop());

        vm.startPrank(address(3));
        address tokenShop = Itest(address(deployCoordinator)).tokenShop();
        Itest(tokenShop).swapNumeraireForExactTokens(DeployCoordTest.TokenInfo({tokenAddresses: tokenAddresses_l, tokenIds: tokenIds_l, tokenAmounts: tokenAmounts_l, tokenTypes: tokenTypes_l}), IFactoryPaperTradingExtended(deployCoordinator.factory()).vaultIndex(firstVault));
        vm.stopPrank();
        emit log_named_uint("vault1value", IVaultValue(firstVault).getValue(0));
        emit log_named_uint("vault1value", IVaultValue(secondVault).getValue(1));


        helper = new HelperContract();
        helper.storeAddresses(HelperContract.HelperAddresses({
                              factory: address(deployCoordinator.factory()),
                              vaultLogic: address(deployCoordinator.vault()),
                              mainReg: address(deployCoordinator.mainRegistry()),
                              erc20sub: address(deployCoordinator.standardERC20Registry()),
                              erc721sub: address(deployCoordinator.floorERC721Registry()),
                              oracleHub: address(deployCoordinator.oracleHub()),
                              irm: address(deployCoordinator.interestRateModule()),
                              liquidator: address(deployCoordinator.liquidator()),
                              stableUsd: address(deployCoordinator.stableUsd()),
                              stableEth: address(deployCoordinator.stableEth()),
                              weth: address(deployCoordinator.weth()),
                              tokenShop: address(deployCoordinator.tokenShop())}
                              ));
        helper.getAllPrices();
    }

    struct TokenInfo {
        address[] tokenAddresses;
        uint256[] tokenIds;
        uint256[] tokenAmounts;
        uint256[] tokenTypes;
    }

    function checkOracle() public {
        uint256 len = assets.length;
        address oracleAddr_t;
        string memory symb;
        for (uint256 i; i < len; ++i) {
            (, , , , symb, , , oracleAddr_t, ) = deployCoordinator.assets(i);
            if (StringHelpers.compareStrings(symb, "mwETH")) {
                emit log_named_address("Orac from assets", oracleAddr_t);
            }
        }
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
