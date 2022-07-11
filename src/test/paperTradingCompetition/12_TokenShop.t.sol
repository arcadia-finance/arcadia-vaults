/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../../lib/forge-std/src/Test.sol";

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../Proxy.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../paperTradingCompetition/ERC721PaperTrading.sol";
import "../../paperTradingCompetition/ERC1155PaperTrading.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";
import "../../paperTradingCompetition/TokenShop.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";

contract TokenShopTest is Test {
    using stdStorage for StdStorage;

    FactoryPaperTrading private factory;
    VaultPaperTrading private vault;
    VaultPaperTrading private proxy;
    address private proxyAddr;
    ERC20PaperTrading private eth;
    ERC20PaperTrading private snx;
    ERC20PaperTrading private link;
    ERC721PaperTrading private bayc;
    ERC20PaperTrading private wbayc;
    ERC1155PaperTrading private interleave;
    OracleHub private oracleHub;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;
    ArcadiaOracle private oracleWbaycToEth;
    ArcadiaOracle private oracleInterleaveToEth;
    ArcadiaOracle private oracleStableUsdToUsd;
    ArcadiaOracle private oracleStableEthToEth;
    MainRegistry private mainRegistry;
    StandardERC20Registry private standardERC20Registry;
    FloorERC721SubRegistry private floorERC721SubRegistry;
    FloorERC1155SubRegistry private floorERC1155SubRegistry;
    InterestRateModule private interestRateModule;
    StablePaperTrading private stableUsd;
    StablePaperTrading private stableEth;
    Liquidator private liquidator;
    TokenShop private tokenShop;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);
    address private stakeContract = address(4);
    address private vaultOwner = address(5);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    address[] public oracleStableUsdToUsdArr = new address[](1);
    address[] public oracleStableEthToUsdArr = new address[](2);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(creatorAddress);
        factory = new FactoryPaperTrading();

        stableUsd = new StablePaperTrading(
            "Arcadia USD Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            address(factory)
        );
        stableEth = new StablePaperTrading(
            "Arcadia ETH Stable Mock",
            "masETH",
            uint8(Constants.stableEthDecimals),
            0x0000000000000000000000000000000000000000,
            address(factory)
        );

        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: address(stableUsd),
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );
        tokenShop = new TokenShop(address(mainRegistry));
        liquidator = new Liquidator(address(factory), address(mainRegistry));

        interestRateModule = new InterestRateModule();
        interestRateModule.setBaseInterestRate(5 * 10**16);

        vault = new VaultPaperTrading();
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factory.confirmNewVaultInfo();

        factory.setLiquidator(address(liquidator));
        factory.setTokenShop(address(tokenShop));
        mainRegistry.setFactory(address(factory));
        tokenShop.setFactory(address(factory));
        stableUsd.setLiquidator(address(liquidator));
        stableEth.setLiquidator(address(liquidator));
        stableUsd.setTokenShop(address(tokenShop));
        stableEth.setTokenShop(address(tokenShop));
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20PaperTrading(
            "ETH Mock",
            "mETH",
            uint8(Constants.ethDecimals),
            address(tokenShop)
        );
        snx = new ERC20PaperTrading(
            "SNX Mock",
            "mSNX",
            uint8(Constants.snxDecimals),
            address(tokenShop)
        );
        link = new ERC20PaperTrading(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals),
            address(tokenShop)
        );
        bayc = new ERC721PaperTrading("BAYC Mock", "mBAYC", address(tokenShop));
        wbayc = new ERC20PaperTrading(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals),
            address(tokenShop)
        );
        interleave = new ERC1155PaperTrading(
            "Interleave Mock",
            "mInterleave",
            address(tokenShop)
        );
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleLinkToUsdDecimals),
            "LINK / USD",
            rateLinkToUsd
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleSnxToEthDecimals),
            "SNX / ETH",
            rateSnxToEth
        );
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "WBAYC / ETH",
            rateWbaycToEth
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / ETH",
            rateInterleaveToEth
        );

        oracleStableUsdToUsd = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableToUsdDecimals),
            "masUSD / USD"
        );
        oracleStableEthToEth = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableEthToEthUnit),
            "masEth / Eth"
        );

        vm.startPrank(creatorAddress);
        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: address(stableEth),
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );

        oracleHub = new OracleHub();

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWbaycToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "WBAYC",
                baseAsset: "ETH",
                oracleAddress: address(oracleWbaycToEth),
                quoteAssetAddress: address(wbayc),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleInterleaveToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "INTERLEAVE",
                baseAsset: "ETH",
                oracleAddress: address(oracleInterleaveToEth),
                quoteAssetAddress: address(interleave),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "masUSD",
                baseAsset: "USD",
                oracleAddress: address(oracleStableUsdToUsd),
                quoteAssetAddress: address(stableUsd),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableEthToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "masETH",
                baseAsset: "ETH",
                oracleAddress: address(oracleStableEthToEth),
                quoteAssetAddress: address(stableEth),
                baseAssetIsNumeraire: true
            })
        );

        standardERC20Registry = new StandardERC20Registry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC721SubRegistry = new FloorERC721SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC1155SubRegistry = new FloorERC1155SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        mainRegistry.addSubRegistry(address(floorERC1155SubRegistry));

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        oracleLinkToUsdArr[0] = address(oracleLinkToUsd);
        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleWbaycToEthEthToUsd[0] = address(oracleWbaycToEth);
        oracleWbaycToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);
        oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
        oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 0,
                assetAddress: address(interleave)
            }),
            emptyList
        );

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleStableUsdToUsdArr,
                assetUnit: uint64(10**Constants.stableDecimals),
                assetAddress: address(stableUsd)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleStableEthToUsdArr,
                assetUnit: uint64(10**Constants.stableEthDecimals),
                assetAddress: address(stableEth)
            }),
            emptyList
        );

        vm.stopPrank();
    }

    //this is a before each
    function setUp() public {}

    function testUsdVault() public {
        vm.prank(vaultOwner);
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
            Constants.UsdNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testEthVault() public {
        vm.prank(vaultOwner);
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
            Constants.EthNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testNonOwnerSwapsNumeraireForExactTokens(
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != vaultOwner);

        vm.startPrank(vaultOwner);
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
            Constants.UsdNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(link);
        tokenAddresses[1] = address(bayc);
        tokenAddresses[2] = address(interleave);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 0;
        tokenIds[2] = 0;

        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[0] = 10**Constants.linkDecimals;
        tokenAmounts[1] = 1;
        tokenAmounts[2] = 10;

        uint256[] memory tokenTypes = new uint256[](3);
        tokenTypes[0] = 0;
        tokenTypes[1] = 1;
        tokenTypes[2] = 2;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("TS_SNFET: You are not the owner");
        tokenShop.swapNumeraireForExactTokens(tokenInfo, vaultId);
        vm.stopPrank();
    }

    function testFailOwnerSwapsNumeraireForExactTokensInsufficientFunds(
        uint32 linkAmount
    ) public {
        vm.startPrank(vaultOwner);
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
            Constants.UsdNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = address(link);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = linkAmount;

        uint256[] memory tokenTypes = new uint256[](1);
        tokenTypes[0] = 0;

        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            tokenAmounts[0]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        vm.assume(linkValueInUsd > 1000000 * Constants.WAD);

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        tokenShop.swapNumeraireForExactTokens(tokenInfo, vaultId);
        vm.stopPrank();
    }

    function testOwnerSwapsNumeraireForExactTokensSucces(
        uint32 linkAmount,
        uint32 interleaveAmount
    ) public {
        vm.startPrank(vaultOwner);
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
            Constants.UsdNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(link);
        tokenAddresses[1] = address(bayc);
        tokenAddresses[2] = address(interleave);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 0;
        tokenIds[2] = 0;

        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[0] = linkAmount;
        tokenAmounts[1] = 1;
        tokenAmounts[2] = interleaveAmount;

        uint256[] memory tokenTypes = new uint256[](3);
        tokenTypes[0] = 0;
        tokenTypes[1] = 1;
        tokenTypes[2] = 2;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );

        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            tokenAmounts[0]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 baycValueInEth = (Constants.WAD *
            rateWbaycToEth *
            tokenAmounts[1]) / 10**Constants.oracleWbaycToEthDecimals;
        uint256 baycValueInUsd = (baycValueInEth * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 interleaveValueInEth = (Constants.WAD *
            rateInterleaveToEth *
            tokenAmounts[2]) / 10**Constants.oracleInterleaveToEthDecimals;
        uint256 interleaveValueInUsd = (interleaveValueInEth * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        uint256 totalValue = linkValueInUsd +
            baycValueInUsd +
            interleaveValueInUsd;
        vm.assume(totalValue <= 1000000 * Constants.WAD);

        tokenShop.swapNumeraireForExactTokens(tokenInfo, vaultId);

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testNonOwnerSwapsExactTokensForNumeraire(
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != vaultOwner);

        vm.startPrank(vaultOwner);
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
            Constants.EthNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(link);
        tokenAddresses[1] = address(bayc);
        tokenAddresses[2] = address(interleave);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 0;
        tokenIds[2] = 0;

        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[0] = 10**Constants.linkDecimals;
        tokenAmounts[1] = 1;
        tokenAmounts[2] = 10;

        uint256[] memory tokenTypes = new uint256[](3);
        tokenTypes[0] = 0;
        tokenTypes[1] = 1;
        tokenTypes[2] = 2;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );
        vm.stopPrank();

        vm.prank(unprivilegedAddress);
        vm.expectRevert("TS_SETFN: You are not the owner");
        tokenShop.swapExactTokensForNumeraire(tokenInfo, vaultId);
        vm.stopPrank();
    }

    function testFailOwnerSwapsExactTokensForNumeraireInsufficientFunds(
        uint32 linkAmount
    ) public {
        vm.assume(linkAmount > 0);
        vm.startPrank(vaultOwner);
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
            Constants.EthNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = address(link);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = linkAmount;

        uint256[] memory tokenTypes = new uint256[](1);
        tokenTypes[0] = 0;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        tokenShop.swapExactTokensForNumeraire(tokenInfo, vaultId);
        vm.stopPrank();
    }

    function testOwnerSwapsExactTokensForNumeraireSucces(
        uint32 linkAmount,
        uint32 interleaveAmount
    ) public {
        vm.startPrank(vaultOwner);
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
            Constants.EthNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        uint256 vaultId = factory.vaultIndex(proxyAddr);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(link);
        tokenAddresses[1] = address(bayc);
        tokenAddresses[2] = address(interleave);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 0;
        tokenIds[2] = 0;

        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[0] = linkAmount;
        tokenAmounts[1] = 1;
        tokenAmounts[2] = interleaveAmount;

        uint256[] memory tokenTypes = new uint256[](3);
        tokenTypes[0] = 0;
        tokenTypes[1] = 1;
        tokenTypes[2] = 2;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );

        uint256 linkValueInUsd = (Constants.WAD *
            rateLinkToUsd *
            tokenAmounts[0]) /
            10**(Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 baycValueInEth = (Constants.WAD *
            rateWbaycToEth *
            tokenAmounts[1]) / 10**Constants.oracleWbaycToEthDecimals;
        uint256 baycValueInUsd = (baycValueInEth * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 interleaveValueInEth = (Constants.WAD *
            rateInterleaveToEth *
            tokenAmounts[2]) / 10**Constants.oracleInterleaveToEthDecimals;
        uint256 interleaveValueInUsd = (interleaveValueInEth * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        uint256 totalValue = linkValueInUsd +
            baycValueInUsd +
            interleaveValueInUsd;
        vm.assume(totalValue <= 1000000 * Constants.WAD);

        tokenShop.swapNumeraireForExactTokens(tokenInfo, vaultId);

        tokenShop.swapExactTokensForNumeraire(tokenInfo, vaultId);

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }
}
