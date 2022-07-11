/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";
import "../utils/Constants.sol";

import "../Factory.sol";
import "../Proxy.sol";
import "../Vault.sol";
import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../Stable.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../AssetRegistry/FloorERC721SubRegistry.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/FloorERC1155SubRegistry.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract vaultTests is Test {
    using stdStorage for StdStorage;

    Factory internal factoryContr;
    Vault private vault;
    ERC20Mock internal eth;
    ERC20Mock internal snx;
    ERC20Mock internal link;
    ERC20Mock internal safemoon;
    ERC721Mock internal bayc;
    ERC721Mock internal mayc;
    ERC721Mock internal dickButs;
    ERC20Mock internal wbayc;
    ERC20Mock internal wmayc;
    ERC1155Mock internal interleave;
    OracleHub internal oracleHub;
    ArcadiaOracle internal oracleEthToUsd;
    ArcadiaOracle internal oracleLinkToUsd;
    ArcadiaOracle internal oracleSnxToEth;
    ArcadiaOracle internal oracleWbaycToEth;
    ArcadiaOracle internal oracleWmaycToUsd;
    ArcadiaOracle internal oracleInterleaveToEth;
    MainRegistry internal mainRegistry;
    StandardERC20Registry internal standardERC20Registry;
    FloorERC721SubRegistry internal floorERC721SubRegistry;
    FloorERC1155SubRegistry internal floorERC1155SubRegistry;
    InterestRateModule internal interestRateModule;
    Stable internal stable;
    Liquidator internal liquidator;


    address internal creatorAddress = address(1);
    address internal tokenCreatorAddress = address(2);
    address internal oracleOwner = address(3);
    address internal unprivilegedAddress = address(4);
    address internal stakeContract = address(5);
    address internal vaultOwner = address(6);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleLinkToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleWbaycToEthEthToUsd = new address[](2);
    address[] public oracleWmaycToUsdArr = new address[](1);
    address[] public oracleInterleaveToEthEthToUsd = new address[](2);

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.prank(creatorAddress);
        factoryContr = new Factory();

        vm.startPrank(tokenCreatorAddress);

        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        eth.mint(tokenCreatorAddress, 200000 * 10**Constants.ethDecimals);

        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        snx.mint(tokenCreatorAddress, 200000 * 10**Constants.snxDecimals);

        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );
        link.mint(tokenCreatorAddress, 200000 * 10**Constants.linkDecimals);

        safemoon = new ERC20Mock(
            "Safemoon Mock",
            "mSFMN",
            uint8(Constants.safemoonDecimals)
        );
        safemoon.mint(
            tokenCreatorAddress,
            200000 * 10**Constants.safemoonDecimals
        );

        bayc = new ERC721Mock("BAYC Mock", "mBAYC");
        bayc.mint(tokenCreatorAddress, 0);
        bayc.mint(tokenCreatorAddress, 1);
        bayc.mint(tokenCreatorAddress, 2);
        bayc.mint(tokenCreatorAddress, 3);

        mayc = new ERC721Mock("MAYC Mock", "mMAYC");
        mayc.mint(tokenCreatorAddress, 0);

        dickButs = new ERC721Mock("DickButs Mock", "mDICK");
        dickButs.mint(tokenCreatorAddress, 0);

        wbayc = new ERC20Mock(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals)
        );
        wbayc.mint(tokenCreatorAddress, 100000 * 10**Constants.wbaycDecimals);

        interleave = new ERC1155Mock("Interleave Mock", "mInterleave");
        interleave.mint(tokenCreatorAddress, 1, 100000);

        vm.stopPrank();

        vm.prank(creatorAddress);
        oracleHub = new OracleHub();

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
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "WMAYC / USD",
            rateWmaycToUsd
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / ETH"
        );

        vm.startPrank(creatorAddress);
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
                oracleUnit: uint64(Constants.oracleWmaycToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "WMAYC",
                baseAsset: "USD",
                oracleAddress: address(oracleWmaycToUsd),
                quoteAssetAddress: address(wmayc),
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
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        eth.transfer(vaultOwner, 100000 * 10**Constants.ethDecimals);
        link.transfer(vaultOwner, 100000 * 10**Constants.linkDecimals);
        snx.transfer(vaultOwner, 100000 * 10**Constants.snxDecimals);
        safemoon.transfer(vaultOwner, 100000 * 10**Constants.safemoonDecimals);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        dickButs.transferFrom(tokenCreatorAddress, vaultOwner, 0);
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        eth.transfer(unprivilegedAddress, 1000 * 10**Constants.ethDecimals);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        interestRateModule = new InterestRateModule();
        interestRateModule.setBaseInterestRate(5 * 10**16);
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        stable = new Stable(
            "Arcadia Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            address(factoryContr)
        );
        vm.stopPrank();

        oracleEthToUsdArr[0] = address(oracleEthToUsd);

        oracleLinkToUsdArr[0] = address(oracleLinkToUsd);

        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);

        oracleWbaycToEthEthToUsd[0] = address(oracleWbaycToEth);
        oracleWbaycToEthEthToUsd[1] = address(oracleEthToUsd);

        oracleWmaycToUsdArr[0] = address(oracleWmaycToUsd);

        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);

        // vm.prank(creatorAddress);
        // liquidator = new Liquidator(0x0000000000000000000000000000000000000000, address(mainRegistry));
    }

    //this is a before each
    function setUp() public virtual {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: address(stable),
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );
        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: address(stable),
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );
        vm.stopPrank();

        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        vm.prank(creatorAddress);
        factoryContr.confirmNewVaultInfo();

        vm.startPrank(creatorAddress);
        mainRegistry.setFactory(address(factoryContr));

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
        liquidator = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = new Vault();
        stable.transfer(address(0), stable.balanceOf(vaultOwner));
        vm.stopPrank();

        uint256 slot = stdstore
            .target(address(factoryContr))
            .sig(factoryContr.isVault.selector)
            .with_key(address(vault))
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factoryContr), loc, mockedCurrentTokenId);

        // uint256 slot2 = stdstore
        //         .target(address(vault))
        //         .sig(vault.owner.selector)
        //         .find();
        // bytes32 loc2 = bytes32(slot2);
        // bytes32 newOwner = bytes32(abi.encode(vaultOwner));
        // vm.store(address(vault), loc2, newOwner);

        vm.prank(address(vault));
        stable.mint(tokenCreatorAddress, 100000 * 10**Constants.stableDecimals);

        vm.prank(tokenCreatorAddress);
        stable.setLiquidator(address(liquidator));

        vm.startPrank(vaultOwner);
        vault.initialize(
            vaultOwner,
            address(mainRegistry),
            uint8(Constants.UsdNumeraire),
            address(stable),
            address(stakeContract),
            address(interestRateModule)
        );
        bayc.setApprovalForAll(address(vault), true);
        mayc.setApprovalForAll(address(vault), true);
        dickButs.setApprovalForAll(address(vault), true);
        interleave.setApprovalForAll(address(vault), true);
        eth.approve(address(vault), type(uint256).max);
        link.approve(address(vault), type(uint256).max);
        snx.approve(address(vault), type(uint256).max);
        safemoon.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testShouldFailIfLengthOfListDoesNotMatch(
        uint8 addrLen,
        uint8 idLen,
        uint8 amountLen,
        uint8 typesLen
    ) public virtual {
        vm.startPrank(vaultOwner);
        assertEq(vault.owner(), vaultOwner);

        vm.assume(
            (addrLen != idLen && addrLen != amountLen && addrLen != typesLen)
        );
        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; i++) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        uint256[] memory assetTypes = new uint256[](typesLen);
        for (uint256 l; l < typesLen; l++) {
            assetTypes[l] = l;
        }

        vm.expectRevert("Length mismatch");
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testShouldFailIfERC20IsNotWhitelisted(address inputAddr)
        public
        virtual
    {
        vm.startPrank(vaultOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.expectRevert("Not all assets are whitelisted!");
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testShouldFailIfERC721IsNotWhitelisted(
        address inputAddr,
        uint256 id
    ) public virtual {
        vm.startPrank(vaultOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.expectRevert("Not all assets are whitelisted!");
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        console.log("test");
        emit log("test");
    }

    function testSingleERC20Deposit(uint16 amount) public virtual {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10**Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault._erc20Stored(0), address(eth));
    }

    function testMultipleSameERC20Deposits(uint16 amount) public virtual {
        vm.assume(amount <= 50000);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.linkCreditRatingUsd;
        assetCreditRatings[1] = Constants.linkCreditRatingEth;

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatings
        );

        //(uint256 erc20StoredPre,,,) = vault.getLengths();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10**Constants.linkDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        (uint256 erc20StoredDuring, , , ) = vault.getLengths();

        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        (uint256 erc20StoredAfter, , , ) = vault.getLengths();

        assertEq(erc20StoredDuring, erc20StoredAfter);
    }

    function testSingleERC721Deposit() public virtual {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.baycCreditRatingUsd;
        assetCreditRatings[1] = Constants.baycCreditRatingEth;

        vm.prank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault._erc721Stored(0), address(bayc));
    }

    function testMultipleERC721Deposits() public virtual {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.baycCreditRatingUsd;
        assetCreditRatings[1] = Constants.baycCreditRatingEth;

        vm.prank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault._erc721Stored(0), address(bayc));
        (, uint256 erc721LengthFirst, , ) = vault.getLengths();
        assertEq(erc721LengthFirst, 1);

        assetIds[0] = 3;
        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault._erc721Stored(1), address(bayc));
        (, uint256 erc721LengthSecond, , ) = vault.getLengths();
        assertEq(erc721LengthSecond, 2);

        assertEq(vault._erc721TokenIds(0), 1);
        assertEq(vault._erc721TokenIds(1), 3);
    }

    function testSingleERC1155Deposit() public virtual {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.interleaveCreditRatingUsd;
        assetCreditRatings[1] = Constants.interleaveCreditRatingEth;

        vm.prank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 2;

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault._erc1155Stored(0), address(interleave));
        assertEq(vault._erc1155TokenIds(0), 1);
    }

    function testDepositERC20ERC721(uint8 erc20Amount1, uint8 erc20Amount2)
        public
        virtual
    {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 2;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20Amount1 * 10**Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10**Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256[] memory assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 1;

        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatingsERC721 = new uint256[](2);
        assetCreditRatingsERC721[0] = Constants.baycCreditRatingUsd;
        assetCreditRatingsERC721[1] = Constants.baycCreditRatingEth;

        uint256[] memory assetCreditRatingsLink = new uint256[](2);
        assetCreditRatingsLink[0] = Constants.linkCreditRatingUsd;
        assetCreditRatingsLink[1] = Constants.linkCreditRatingEth;

        uint256[] memory assetCreditRatingsEth = new uint256[](2);
        assetCreditRatingsEth[0] = Constants.ethCreditRatingUsd;
        assetCreditRatingsEth[1] = Constants.ethCreditRatingEth;

        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            assetCreditRatingsERC721
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatingsLink
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatingsEth
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDepositERC20ERC721ERC1155(
        uint8 erc20Amount1,
        uint8 erc20Amount2,
        uint8 erc1155Amount
    ) public virtual {
        address[] memory assetAddresses = new address[](4);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);
        assetAddresses[3] = address(interleave);

        uint256[] memory assetIds = new uint256[](4);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;
        assetIds[3] = 1;

        uint256[] memory assetAmounts = new uint256[](4);
        assetAmounts[0] = erc20Amount1 * 10**Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10**Constants.linkDecimals;
        assetAmounts[2] = 1;
        assetAmounts[3] = erc1155Amount;

        uint256[] memory assetTypes = new uint256[](4);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 1;
        assetTypes[3] = 2;

        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatingsERC721 = new uint256[](2);
        assetCreditRatingsERC721[0] = Constants.baycCreditRatingUsd;
        assetCreditRatingsERC721[1] = Constants.baycCreditRatingEth;

        uint256[] memory assetCreditRatingsLink = new uint256[](2);
        assetCreditRatingsLink[0] = Constants.linkCreditRatingUsd;
        assetCreditRatingsLink[1] = Constants.linkCreditRatingEth;

        uint256[] memory assetCreditRatingsEth = new uint256[](2);
        assetCreditRatingsEth[0] = Constants.ethCreditRatingUsd;
        assetCreditRatingsEth[1] = Constants.ethCreditRatingEth;

        uint256[] memory assetCreditRatingsInterleave = new uint256[](2);
        assetCreditRatingsInterleave[0] = Constants.interleaveCreditRatingUsd;
        assetCreditRatingsInterleave[1] = Constants.interleaveCreditRatingEth;

        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            assetCreditRatingsERC721
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatingsLink
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatingsEth
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            assetCreditRatingsInterleave
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDepositOnlyByOwner(address sender) public virtual {
        vm.assume(sender != vaultOwner);

        vm.startPrank(sender);

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;
        vm.stopPrank();

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10**Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vm.expectRevert("You are not the owner");
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testWithdrawERC20NoDebt(uint8 baseAmountDeposit) public virtual {
        uint256 valueAmount = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * baseAmountDeposit;

        Assets memory assetInfo = depositEthInVault(
            baseAmountDeposit,
            vaultOwner
        );

        uint256 vaultValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(vaultValue, valueAmount);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(vault), vaultOwner, assetInfo.assetAmounts[0]);
        vault.withdraw(
            assetInfo.assetAddresses,
            assetInfo.assetIds,
            assetInfo.assetAmounts,
            assetInfo.assetTypes
        );

        uint256 vaultValueAfter = vault.getValue(uint8(Constants.UsdNumeraire));
        assertEq(vaultValueAfter, 0);
        vm.stopPrank();
    }

    function testTakeCredit(uint8 baseAmountDeposit, uint8 baseAmountCredit)
        public
        virtual
    {
        uint256 amountDeposit = baseAmountDeposit * Constants.WAD;
        uint128 amountCredit = uint128(baseAmountCredit * Constants.WAD);

        (, uint16 _collThres, , , , ) = vault.debt();

        vm.assume((amountDeposit * 100) / _collThres >= amountCredit);

        depositEthInVault(baseAmountDeposit, vaultOwner);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), vaultOwner, amountCredit);
        vault.takeCredit(amountCredit);

        assertEq(stable.balanceOf(vaultOwner), amountCredit);
        assertEq(vault.getOpenDebt(), amountCredit);
        //no blocks have passed
    }

    struct Assets {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
        uint256[] assetTypes;
    }

    function testWithdrawERC20fterTakingCredit(
        uint8 baseAmountDeposit,
        uint32 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public virtual {
        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * baseAmountDeposit;
        uint128 amountCredit = uint128(
            baseAmountCredit * 10**Constants.stableDecimals
        );
        uint256 amountWithdraw = baseAmountWithdraw * 10**Constants.ethDecimals;
        uint256 valueWithdraw = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * baseAmountWithdraw;
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        (, uint16 _collThres, , , , ) = vault.debt();

        vm.assume(
            amountCredit < ((valueDeposit - valueWithdraw) * 100) / _collThres
        );

        Assets memory assetInfo = depositEthInVault(
            baseAmountDeposit,
            vaultOwner
        );
        vm.startPrank(vaultOwner);
        vault.takeCredit(amountCredit);
        assetInfo.assetAmounts[0] = amountWithdraw;
        vault.withdraw(
            assetInfo.assetAddresses,
            assetInfo.assetIds,
            assetInfo.assetAmounts,
            assetInfo.assetTypes
        );
        vm.stopPrank();

        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));
        uint256 expectedValue = valueDeposit - valueWithdraw;

        assertEq(expectedValue, actualValue);
    }

    function testNotAllowWithdrawERC20fterTakingCredit(
        uint8 baseAmountDeposit,
        uint24 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public virtual {
        vm.assume(baseAmountCredit > 0);
        vm.assume(baseAmountWithdraw > 0);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * baseAmountDeposit;
        uint256 amountCredit = baseAmountCredit * 10**Constants.stableDecimals;
        uint256 amountWithdraw = baseAmountWithdraw * 10**Constants.ethDecimals;
        uint256 ValueWithdraw = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * baseAmountWithdraw;

        (, uint16 _collThres, , , , ) = vault.debt();

        vm.assume(amountCredit <= (valueDeposit * 100) / _collThres);
        vm.assume(
            amountCredit > ((valueDeposit - ValueWithdraw) * 100) / _collThres
        );

        Assets memory assetInfo = depositEthInVault(
            baseAmountDeposit,
            vaultOwner
        );
        vm.startPrank(vaultOwner);
        vault.takeCredit(uint128(amountCredit));
        assetInfo.assetAmounts[0] = amountWithdraw;
        vm.expectRevert("V_W: coll. value too low!");
        vault.withdraw(
            assetInfo.assetAddresses,
            assetInfo.assetIds,
            assetInfo.assetAmounts,
            assetInfo.assetTypes
        );
        vm.stopPrank();
    }

    function testWithrawERC721AfterTakingCredit(
        uint128[] calldata tokenIdsDeposit,
        uint8 baseAmountCredit
    ) public virtual {
        vm.assume(tokenIdsDeposit.length < 50);
        //test speed
        uint128 amountCredit = uint128(
            baseAmountCredit * 10**Constants.stableDecimals
        );

        (, uint256[] memory assetIds, , ) = depositBaycInVault(
            tokenIdsDeposit,
            vaultOwner
        );

        uint256 randomAmounts = assetIds.length > 0
            ? uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "testWithrawERC721AfterTakingCredit(uint256[],uint8)",
                        assetIds,
                        baseAmountCredit
                    )
                )
            ) % assetIds.length
            : 0;

        (, uint16 _collThres, , , , ) = vault.debt();

        uint256 rateInUsd = (((Constants.WAD * rateWbaycToEth) /
            10**Constants.oracleWbaycToEthDecimals) * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 valueOfDeposit = rateInUsd * assetIds.length;

        uint256 valueOfWithdrawal = (rateInUsd *
            randomAmounts *
            Constants.WAD) / 10**Constants.oracleEthToUsdDecimals;

        vm.assume((valueOfDeposit * 100) / _collThres >= amountCredit);
        vm.assume(valueOfWithdrawal < valueOfDeposit);
        vm.assume(
            amountCredit <
                ((valueOfDeposit - valueOfWithdrawal) * 100) / _collThres
        );

        vm.startPrank(vaultOwner);
        vault.takeCredit(amountCredit);

        uint256[] memory withdrawalIds = new uint256[](randomAmounts);
        address[] memory withdrawalAddresses = new address[](randomAmounts);
        uint256[] memory withdrawalAmounts = new uint256[](randomAmounts);
        uint256[] memory withdrawalTypes = new uint256[](randomAmounts);
        for (uint256 i; i < randomAmounts; i++) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
            withdrawalTypes[i] = 1;
        }

        vault.withdraw(
            withdrawalAddresses,
            withdrawalIds,
            withdrawalAmounts,
            withdrawalTypes
        );

        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));
        uint256 expectedValue = valueOfDeposit - valueOfWithdrawal;

        assertEq(expectedValue, actualValue);
    }

    function testNotAllowERC721Withdraw(
        uint128[] calldata tokenIdsDeposit,
        uint8 amountsWithdrawn
    ) public virtual {
        vm.assume(tokenIdsDeposit.length < 50);
        //test speed

        (, uint256[] memory assetIds, , ) = depositBaycInVault(
            tokenIdsDeposit,
            vaultOwner
        );
        vm.assume(
            assetIds.length >= amountsWithdrawn &&
                assetIds.length > 1 &&
                amountsWithdrawn > 1
        );

        (, uint16 _collThres, , , , ) = vault.debt();
        uint256 rateInUsd = (((Constants.WAD * rateWbaycToEth) /
            10**Constants.oracleWbaycToEthDecimals) * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        uint128 maxAmountCredit = uint128(
            ((assetIds.length - amountsWithdrawn) * rateInUsd * 100) /
                _collThres
        );

        vm.startPrank(vaultOwner);
        vault.takeCredit(maxAmountCredit + 1);

        uint256[] memory withdrawalIds = new uint256[](amountsWithdrawn);
        address[] memory withdrawalAddresses = new address[](amountsWithdrawn);
        uint256[] memory withdrawalAmounts = new uint256[](amountsWithdrawn);
        uint256[] memory withdrawalTypes = new uint256[](amountsWithdrawn);
        for (uint256 i; i < amountsWithdrawn; i++) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
            withdrawalTypes[i] = 1;
        }

        vm.expectRevert("V_W: coll. value too low!");
        vault.withdraw(
            withdrawalAddresses,
            withdrawalIds,
            withdrawalAmounts,
            withdrawalTypes
        );
    }

    function testNotAllowedToWithdrawnByNonOwner(
        uint8 depositAmount,
        uint8 withdrawalAmount,
        address sender
    ) public virtual {
        vm.assume(sender != vaultOwner);
        vm.assume(depositAmount > withdrawalAmount);
        Assets memory assetInfo = depositEthInVault(depositAmount, vaultOwner);

        assetInfo.assetAmounts[0] =
            withdrawalAmount *
            10**Constants.ethDecimals;
        vm.startPrank(sender);
        vm.expectRevert("You are not the owner");
        vault.withdraw(
            assetInfo.assetAddresses,
            assetInfo.assetIds,
            assetInfo.assetAmounts,
            assetInfo.assetTypes
        );
    }

    function testFetchVaultValue(uint8 depositAmount) public virtual {
        depositEthInVault(depositAmount, vaultOwner);

        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * depositAmount;
        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(expectedValue, actualValue);
    }

    function testGetValueGasUsage(
        uint8 depositAmount,
        uint128[] calldata tokenIds
    ) public virtual {
        vm.assume(tokenIds.length <= 5);
        vm.assume(depositAmount > 0);
        depositEthInVault(depositAmount, vaultOwner);
        depositLinkInVault(depositAmount, vaultOwner);
        depositBaycInVault(tokenIds, vaultOwner);

        uint256 gasStart = gasleft();
        vault.getValue(uint8(Constants.UsdNumeraire));
        uint256 gasAfter = gasleft();
        emit log_int(int256(gasStart - gasAfter));
        assertLt(gasStart - gasAfter, 200000);
    }

    function testGetDebtAtStart() public virtual {
        uint256 openDebt = vault.getOpenDebt();
        assertEq(openDebt, 0);
    }

    function testGetRemainingCreditAtStart() public virtual {
        uint256 remainingCredit = vault.getRemainingCredit();
        assertEq(remainingCredit, 0);
    }

    function testGetRemainingCredit(uint8 amount) public virtual {
        depositEthInVault(amount, vaultOwner);

        uint256 depositValue = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * amount;
        (, uint16 _collThres, , , , ) = vault.debt();

        uint256 expectedRemaining = (depositValue * 100) / _collThres;
        assertEq(expectedRemaining, vault.getRemainingCredit());
    }

    function testGetRemainingCreditAfterTopUp(
        uint8 amountEth,
        uint8 amountLink,
        uint128[] calldata tokenIds
    ) public virtual {
        vm.assume(tokenIds.length < 10 && tokenIds.length > 1);
        (, uint16 _collThres, , , , ) = vault.debt();

        depositEthInVault(amountEth, vaultOwner);
        uint256 depositValueEth = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * amountEth;
        assertEq(
            (depositValueEth * 100) / _collThres,
            vault.getRemainingCredit()
        );

        depositLinkInVault(amountLink, vaultOwner);
        uint256 depositValueLink = ((Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals) * amountLink;
        assertEq(
            ((depositValueEth + depositValueLink) * 100) / _collThres,
            vault.getRemainingCredit()
        );

        (, uint256[] memory assetIds, , ) = depositBaycInVault(
            tokenIds,
            vaultOwner
        );
        uint256 depositBaycValue = ((Constants.WAD *
            rateWbaycToEth *
            rateEthToUsd) /
            10 **
                (Constants.oracleEthToUsdDecimals +
                    Constants.oracleWbaycToEthDecimals)) * assetIds.length;
        assertEq(
            ((depositValueEth + depositValueLink + depositBaycValue) * 100) /
                _collThres,
            vault.getRemainingCredit()
        );
    }

    function testGetRemainingCreditAfterTakingCredit(
        uint8 amountEth,
        uint128 amountCredit
    ) public virtual {
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * amountEth;

        (, uint16 _collThres, , , , ) = vault.debt();

        vm.assume((depositValue * 100) / _collThres > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.prank(vaultOwner);
        vault.takeCredit(amountCredit);

        uint256 actualRemainingCredit = vault.getRemainingCredit();
        uint256 expectedRemainingCredit = (depositValue * 100) /
            _collThres -
            amountCredit;

        assertEq(expectedRemainingCredit, actualRemainingCredit);
    }

    function testInitializeWithZeroInterest() public virtual {
        (
            uint256 _openDebt,
            ,
            ,
            uint64 _yearlyInterestRate,
            uint32 _lastBlock,

        ) = vault.debt();

        assertEq(_openDebt, 0);
        assertEq(_yearlyInterestRate, 0);
        assertEq(_lastBlock, 0);
    }

    function testTakeCreditAsNonOwner(uint8 amountEth, uint128 amountCredit)
        public
        virtual
    {
        vm.assume(unprivilegedAddress != vaultOwner);
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals) * amountEth;
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume((depositValue * 100) / _collThres > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("You are not the owner");
        vault.takeCredit(amountCredit);
    }

    struct debtInfo {
        uint256 _openDebt;
        uint16 _collThres; //factor 100
        uint8 _liqThres; //factor 100
        uint64 _yearlyInterestRate; //factor 10**18
        uint32 _lastBlock;
        uint8 _numeraire;
    }

    function testMinCollValueUnchecked() public virtual {
        //uint256 minCollValue;
        //unchecked {minCollValue = uint256(debt._openDebt) * debt._collThres / 100;}
        assertTrue(
            uint256(type(uint128).max) * type(uint16).max < type(uint256).max
        );
    }

    function testCheckBaseUnchecked() public virtual {
        uint256 base256 = uint128(1e18) + type(uint64).max + 1;
        uint128 base128 = uint128(uint128(1e18) + type(uint64).max + 1);

        //assert that 1e18 + uint64 < uint128 can't overflow
        assertTrue(base256 == base128);
    }

    //overflows from deltaBlocks = 894262060268226281981748468
    function testCheckExponentUnchecked() public virtual {
        uint256 yearlyBlocks = 2628000;
        uint256 maxDeltaBlocks = (uint256(type(uint128).max) *
            uint256(yearlyBlocks)) / 10**18;

        uint256 exponent256 = (maxDeltaBlocks * 1e18) / yearlyBlocks;
        uint128 exponent128 = uint128(
            (maxDeltaBlocks * uint256(1e18)) / yearlyBlocks
        );

        assertTrue(exponent256 == exponent128);

        uint256 exponent256Overflow = (((maxDeltaBlocks + 1) * 1e18) /
            yearlyBlocks);
        uint128 exponent128Overflow = uint128(
            ((maxDeltaBlocks + 1) * 1e18) / yearlyBlocks
        );

        assertTrue(exponent256Overflow != exponent128Overflow);
        assertTrue(
            exponent128Overflow == exponent256Overflow - type(uint128).max - 1
        );
    }

    function testCheckUnrealisedDebtUnchecked(
        uint64 base,
        uint24 deltaBlocks,
        uint128 openDebt
    ) public virtual {
        vm.assume(base <= 10 * 10**18);
        //1000%
        vm.assume(base >= 10**18);
        vm.assume(deltaBlocks <= 13140000);
        //5 year
        vm.assume(openDebt <= type(uint128).max / (10**5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        uint256 yearlyBlocks = 2628000;
        uint128 exponent = uint128(
            ((uint256(deltaBlocks)) * 1e18) / yearlyBlocks
        );
        vm.assume(LogExpMath.pow(base, exponent) > 0);

        emit log_named_uint("logexp", LogExpMath.pow(base, exponent));

        //uint256 openDebt = type(uint256).max / (2^255 - 1) / 10^20;

        uint256 unRealisedDebt256 = (uint256(openDebt) *
            (LogExpMath.pow(base, exponent) - 1e18)) / 1e18;
        uint128 unRealisedDebt128 = uint128(
            (openDebt * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18
        );

        assertEq(unRealisedDebt256, unRealisedDebt128);
    }

    /*
      We assume a situation where the base and exponent are within "logical" (yet extreme) boundries.
      Within this assumption, we let the open debt vary over all possible values within the assumption.
      We then check whether checked uint256 calculations will be equal to unchecked uint128 calcs.
      The assumptions are:
        * 1000% interest rate
        * never synced any debt during 5 years
    **/
    function testSyncDebtUnchecked(
        uint64 base,
        uint24 deltaBlocks,
        uint128 openDebt
    ) public virtual {
        vm.assume(base <= 10 * 10**18);
        //1000%
        vm.assume(base >= 10**18);
        //No negative interest rate possible
        vm.assume(deltaBlocks <= 13140000);
        //5 year
        vm.assume(openDebt <= type(uint128).max / (10**5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        (
            ,
            uint16 _collThres,
            ,
            uint64 _yearlyInterestRate,
            ,
            uint8 _numeraire
        ) = vault.debt();
        uint128 amountEthToDeposit = uint128(
            ((openDebt / rateEthToUsd / 10**18) *
                10**(Constants.oracleEthToUsdDecimals + Constants.ethDecimals) *
                _collThres) / 100
        );

        uint256 yearlyBlocks = 2628000;
        uint128 exponent = uint128(
            ((uint256(deltaBlocks)) * 1e18) / yearlyBlocks
        );

        vm.prank(creatorAddress);
        interestRateModule.setBaseInterestRate(base - 1e18);
        //note this will not work anymore if any credit-rating is set!!

        //uint256 remainingCredit = depositEthAndTakeMaxCredit(10*10**6 * 10**18); //10m ETH
        uint256 remainingCredit = depositEthAndTakeMaxCredit(
            amountEthToDeposit
        );
        //10m ETH

        uint256 _lastBlock = block.number;

        (, _collThres, , _yearlyInterestRate, , _numeraire) = vault.debt();
        assertTrue(_yearlyInterestRate == base - 1e18);

        vm.roll(block.number + deltaBlocks);

        uint128 unRealisedDebt;

        debtInfo memory debtLocal;
        debtLocal._openDebt = remainingCredit;
        debtLocal._collThres = _collThres;
        debtLocal._numeraire = _numeraire;
        debtLocal._lastBlock = uint32(_lastBlock);
        debtLocal._yearlyInterestRate = _yearlyInterestRate;

        unRealisedDebt = uint128(
            (debtLocal._openDebt * (LogExpMath.pow(base, exponent) - 1e18)) /
                1e18
        );

        debtLocal._openDebt += unRealisedDebt;
        debtLocal._lastBlock = uint32(block.number);

        vault.syncDebt();

        (uint256 _openDebt, , , , , ) = vault.debt();

        assertEq(debtLocal._openDebt, _openDebt);
    }

    function testGetOpenDebtUnchecked(uint32 blocksToRoll) public virtual {
        vm.assume(blocksToRoll <= 255555555);
        //up to the year 2122
        (
            ,
            uint16 _collThres,
            ,
            uint64 _yearlyInterestRate,
            ,
            uint8 _numeraire
        ) = vault.debt();
        uint128 amountEthToDeposit = uint128(
            (((10 * 10**9 * 10**18) / rateEthToUsd / 10**18) *
                10**(Constants.oracleEthToUsdDecimals + Constants.ethDecimals) *
                _collThres) / 100
        );
        //equivalent to 10bn USD debt
        uint256 remainingCredit = depositEthAndTakeMaxCredit(
            amountEthToDeposit
        );
        //10bn USD debt
        uint256 _lastBlock = block.number;

        (, _collThres, , _yearlyInterestRate, , _numeraire) = vault.debt();

        vm.roll(block.number + blocksToRoll);

        uint256 base;
        uint256 exponent;
        uint256 unRealisedDebt;

        debtInfo memory debtLocal;
        debtLocal._openDebt = remainingCredit;
        debtLocal._collThres = _collThres;
        debtLocal._numeraire = _numeraire;
        debtLocal._lastBlock = uint32(_lastBlock);
        debtLocal._yearlyInterestRate = _yearlyInterestRate;

        //gas: can't overflow as long as interest remains < 3.4*10**20 %/yr
        //gas: can't overflow: 1e18 + uint64 <<< uint128
        base = 1e18 + debtLocal._yearlyInterestRate;

        //gas: only overflows when blocks.number > ~10**20
        exponent =
            ((block.number - debtLocal._lastBlock) * 1e18) /
            vault.yearlyBlocks();

        emit log_named_uint("base", base);
        emit log_named_uint("exponent", exponent);
        emit log_named_uint("logExp", LogExpMath.pow(base, exponent));
        emit log_named_uint("unRealisedDebt", unRealisedDebt);

        debtLocal._openDebt =
            (debtLocal._openDebt * LogExpMath.pow(base, exponent)) /
            1e18;

        vault.syncDebt();

        uint256 _openDebt;
        (
            _openDebt,
            _collThres,
            ,
            _yearlyInterestRate,
            _lastBlock,
            _numeraire
        ) = vault.debt();

        assertEq(debtLocal._openDebt, _openDebt);
    }

    function testRemainingCreditUnchecked(uint128 amountEth, uint8 factor)
        public
        virtual
    {
        vm.assume(amountEth < 10 * 10**9 * 10**18);

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;
        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        depositERC20InVault(eth, amountEth, vaultOwner);
        vm.prank(vaultOwner);
        vault.takeCredit((((amountEth * 100) / 150) * factor) / 255);

        uint256 currentValue = vault.getValue(uint8(Constants.UsdNumeraire));
        uint256 openDebt = vault.getOpenDebt();
        (, uint16 _collThres, , , , ) = vault.debt();

        uint256 maxAllowedCreditLocal;
        uint256 remainingCreditLocal;
        //gas: cannot overflow unless currentValue is more than
        // 1.15**57 *10**18 decimals, which is too many billions to write out
        maxAllowedCreditLocal = (currentValue * 100) / _collThres;

        //gas: explicit check is done to prevent underflow
        remainingCreditLocal = maxAllowedCreditLocal > openDebt
            ? maxAllowedCreditLocal - openDebt
            : 0;

        uint256 remainingCreditFetched = vault.getRemainingCredit();

        assertEq(remainingCreditLocal, remainingCreditFetched);
    }

    function testTransferOwnershipOfVaultByNonOwner(address sender)
        public
        virtual
    {
        vm.assume(sender != address(factoryContr));
        vm.startPrank(sender);
        vm.expectRevert("VL: Not factory");
        vault.transferOwnership(address(10));
        vm.stopPrank();
    }

    function testTransferOwnership(address to) public virtual {
        vm.assume(to != address(0));
        Vault vault_m = new Vault();

        uint256 slot2 = stdstore
            .target(address(vault_m))
            .sig(vault_m._registryAddress.selector)
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 newReg = bytes32(abi.encode(address(mainRegistry)));
        vm.store(address(vault_m), loc2, newReg);

        assertEq(address(0), vault_m.owner());
        vm.prank(address(factoryContr));
        vault_m.transferOwnership(to);
        assertEq(to, vault_m.owner());

        vault_m = new Vault();
        vault_m.initialize(
            address(this),
            address(mainRegistry),
            uint8(Constants.UsdNumeraire),
            address(stable),
            address(stakeContract),
            address(interestRateModule)
        );
        assertEq(address(this), vault_m.owner());

        vm.prank(address(factoryContr));
        vault_m.transferOwnership(to);
        assertEq(to, vault_m.owner());
    }

    function testTransferOwnershipByNonOwner(address from) public virtual {
        vm.assume(
            from != address(this) &&
                from != address(0) &&
                from != address(factoryContr)
        );
        Vault vault_m = new Vault();
        address to = address(123456);

        uint256 slot2 = stdstore
            .target(address(vault_m))
            .sig(vault_m._registryAddress.selector)
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 newReg = bytes32(abi.encode(address(mainRegistry)));
        vm.store(address(vault_m), loc2, newReg);

        assertEq(address(0), vault_m.owner());

        vm.startPrank(from);
        vm.expectRevert("VL: Not factory");
        vault_m.transferOwnership(to);
        vm.stopPrank();

        assertEq(address(0), vault_m.owner());

        vault_m = new Vault();
        vault_m.initialize(
            address(this),
            address(mainRegistry),
            uint8(Constants.UsdNumeraire),
            address(stable),
            address(stakeContract),
            address(interestRateModule)
        );
        assertEq(address(this), vault_m.owner());

        vm.startPrank(from);
        vm.expectRevert("VL: Not factory");
        vault_m.transferOwnership(to);
        assertEq(address(this), vault_m.owner());
    }

    function depositEthAndTakeMaxCredit(uint128 amountEth)
        public
        returns (uint256)
    {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        emit log_named_uint("AmountInDepositandMax", amountEth);

        depositERC20InVault(eth, amountEth, vaultOwner);
        vm.startPrank(vaultOwner);
        uint256 remainingCredit = vault.getRemainingCredit();
        vault.takeCredit(uint128(remainingCredit));
        vm.stopPrank();

        return remainingCredit;
    }

    function depositERC20InVault(
        ERC20Mock token,
        uint128 amount,
        address sender
    )
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositEthInVault(uint8 amount, address sender)
        public
        returns (Assets memory assetInfo)
    {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.ethCreditRatingUsd;
        assetCreditRatings[1] = Constants.ethCreditRatingEth;

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10**Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();

        assetInfo = Assets({
            assetAddresses: assetAddresses,
            assetIds: assetIds,
            assetAmounts: assetAmounts,
            assetTypes: assetTypes
        });
    }

    function depositLinkInVault(uint8 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.linkCreditRatingUsd;
        assetCreditRatings[1] = Constants.linkCreditRatingEth;

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatings
        );

        assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10**Constants.linkDecimals;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositBaycInVault(uint128[] memory tokenIds, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = Constants.baycCreditRatingUsd;
        assetCreditRatings[1] = Constants.baycCreditRatingEth;

        vm.prank(creatorAddress);
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );

        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIdToWorkWith = tokenIds[i];
            while (bayc.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            bayc.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(bayc);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        vault.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }
}
