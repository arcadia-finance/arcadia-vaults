/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

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

contract EndToEndTest is Test {
    using stdStorage for StdStorage;

    Factory private factory;
    Vault private vault;
    Vault private proxy;
    address private proxyAddr;
    ERC20Mock private eth;
    ERC20Mock private snx;
    ERC20Mock private link;
    ERC20Mock private safemoon;
    ERC721Mock private bayc;
    ERC721Mock private mayc;
    ERC721Mock private dickButs;
    ERC20Mock private wbayc;
    ERC20Mock private wmayc;
    ERC1155Mock private interleave;
    OracleHub private oracleHub;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleLinkToUsd;
    ArcadiaOracle private oracleSnxToEth;
    ArcadiaOracle private oracleWbaycToEth;
    ArcadiaOracle private oracleWmaycToUsd;
    ArcadiaOracle private oracleInterleaveToEth;
    MainRegistry private mainRegistry;
    StandardERC20Registry private standardERC20Registry;
    FloorERC721SubRegistry private floorERC721SubRegistry;
    FloorERC1155SubRegistry private floorERC1155SubRegistry;
    InterestRateModule private interestRateModule;
    Stable private stable;
    Liquidator private liquidator;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);
    address private unprivilegedAddress = address(4);
    address private stakeContract = address(5);
    address private vaultOwner = address(6);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateLinkToUsd = 20 * 10**Constants.oracleLinkToUsdDecimals;
    uint256 rateSnxToEth = 1600000000000000;
    uint256 rateWbaycToEth = 85 * 10**Constants.oracleWbaycToEthDecimals;
    uint256 rateWmaycToUsd = 50000 * 10**Constants.oracleWmaycToUsdDecimals;
    uint256 rateInterleaveToEth =
        1 * 10**(Constants.oracleInterleaveToEthDecimals - 2);

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
            "ETH / USD"
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleLinkToUsdDecimals),
            "LINK / USD"
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleSnxToEthDecimals),
            "SNX / ETH"
        );
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "WBAYC / ETH"
        );
        oracleWmaycToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "WBAYC / USD"
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
            0x0000000000000000000000000000000000000000
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
    }

    //this is a before each
    function setUp() public {
        //emit log_named_address("oracleEthToUsdArr[0]", oracleEthToUsdArr[0]);

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

        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            assetCreditRatings
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            assetCreditRatings
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            assetCreditRatings
        );

        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            assetCreditRatings
        );

        liquidator = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = new Vault();
        stable.transfer(address(0), stable.balanceOf(vaultOwner));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        factory = new Factory();
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factory.confirmNewVaultInfo();
        factory.setLiquidator(address(liquidator));
        liquidator.setFactory(address(factory));
        mainRegistry.setFactory(address(factory));
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        stable.setLiquidator(address(liquidator));
        stable.setFactory(address(factory));
        vm.stopPrank();

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
        proxy = Vault(proxyAddr);

        vm.prank(address(proxy));
        stable.mint(tokenCreatorAddress, 100000 * 10**Constants.stableDecimals);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleSnxToEth.transmit(int256(rateSnxToEth));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        oracleWmaycToUsd.transmit(int256(rateWmaycToUsd));
        oracleInterleaveToEth.transmit(int256(rateInterleaveToEth));
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        stable.approve(address(proxy), type(uint256).max);
        stable.approve(address(liquidator), type(uint256).max);
        vm.stopPrank();
    }

    function testTransferOwnershipStable(address to) public {
        vm.assume(to != address(0));
        Stable stable_m = new Stable(
            "Arcadia Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );

        assertEq(address(this), stable_m.owner());

        stable_m.transferOwnership(to);
        assertEq(to, stable_m.owner());
    }

    function testTransferOwnershipStableByNonOwner(address from) public {
        vm.assume(from != address(this));

        Stable stable_m = new Stable(
            "Arcadia Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        address to = address(12345);

        assertEq(address(this), stable_m.owner());

        vm.startPrank(from);
        vm.expectRevert("Ownable: caller is not the owner");
        stable_m.transferOwnership(to);
        assertEq(address(this), stable_m.owner());
    }

    function testReturnUsdValueOfEth(uint128 amount) public {
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedValue = (valueOfOneEth * amount) /
            10**Constants.ethDecimals;

        depositERC20InVault(eth, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueOfLink(uint128 amount) public {
        uint256 valueOfOneLink = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValue = (valueOfOneLink * amount) /
            10**Constants.linkDecimals;

        depositERC20InVault(link, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueOfSnx(uint128 amount) public {
        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth * rateEthToUsd) /
            10 **
                (Constants.oracleSnxToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValue = (valueOfOneSnx * amount) /
            10**Constants.snxDecimals;

        depositERC20InVault(snx, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnEthValueOfEth(uint128 amount) public {
        uint256 valueOfOneEth = Constants.WAD;
        uint256 expectedValue = (valueOfOneEth * amount) /
            10**Constants.ethDecimals;

        depositERC20InVault(eth, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnEthValueOfLink(uint128 amount) public {
        uint256 valueOfOneLinkInUsd = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValue = (((valueOfOneLinkInUsd * amount) /
            10**Constants.linkDecimals) *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;

        depositERC20InVault(link, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnEthValueOfSnx(uint128 amount) public {
        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth) /
            10**Constants.oracleSnxToEthDecimals;
        uint256 expectedValue = (valueOfOneSnx * amount) /
            10**Constants.snxDecimals;

        depositERC20InVault(snx, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnEthValueOfBayc(uint128[] calldata tokenIds) public {
        vm.assume(tokenIds.length <= 5 && tokenIds.length >= 1);
        uint256 valueOfOneBayc = (Constants.WAD * rateWbaycToEth) /
            10**Constants.oracleWbaycToEthDecimals;
        uint256 expectedValue = valueOfOneBayc * tokenIds.length;

        depositERC721InVault(bayc, tokenIds, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnEthvalueOfInterleave(uint256 tokenId, uint256 amount)
        public
    {
        uint256 valueOfOneIL = (Constants.WAD * rateInterleaveToEth) /
            10**Constants.oracleInterleaveToEthDecimals;
        vm.assume(amount > 0);
        vm.assume(valueOfOneIL < type(uint256).max / amount);
        uint256 expectedValue = valueOfOneIL * amount;

        uint256[] memory assetCreditRatingsInterleave = new uint256[](2);
        assetCreditRatingsInterleave[0] = Constants.interleaveCreditRatingUsd;
        assetCreditRatingsInterleave[1] = Constants.interleaveCreditRatingEth;

        vm.prank(creatorAddress);
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: tokenId,
                assetAddress: address(interleave)
            }),
            assetCreditRatingsInterleave
        );

        depositERC1155InVault(interleave, tokenId, amount, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueEthEth(uint128 amount1, uint128 amount2) public {
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(
            (uint256(amount1) + uint256(amount2)) <
                type(uint256).max / valueOfOneEth
        );

        depositERC20InVault(eth, amount1, vaultOwner);
        uint256 expectedValue = (valueOfOneEth * amount1) /
            10**Constants.ethDecimals;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValue);

        depositERC20InVault(eth, amount2, vaultOwner);
        expectedValue =
            (valueOfOneEth * (uint256(amount1) + uint256(amount2))) /
            10**Constants.ethDecimals;
        actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueEthLink(uint128 amountLink, uint128 amountEth)
        public
    {
        uint256 valueOfOneLink = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValueLink = (valueOfOneLink * amountLink) /
            10**Constants.linkDecimals;
        depositERC20InVault(link, amountLink, vaultOwner);
        uint256 actualValueLink = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValueLink, expectedValueLink);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedValue = actualValueLink +
            (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueEthSnx(uint128 amountSnx, uint128 amountEth)
        public
    {
        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth * rateEthToUsd) /
            10 **
                (Constants.oracleSnxToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueSnx = (valueOfOneSnx * amountSnx) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx, vaultOwner);
        uint256 actualValueSnx = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValueSnx, expectedValueSnx);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedValue = actualValueSnx +
            (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueLinkSnx(uint128 amountLink, uint128 amountSnx)
        public
    {
        uint256 valueOfOneLink = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValueLink = (valueOfOneLink * amountLink) /
            10**Constants.linkDecimals;
        depositERC20InVault(link, amountLink, vaultOwner);
        uint256 actualValueLink = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValueLink, expectedValueLink);

        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth * rateEthToUsd) /
            10 **
                (Constants.oracleSnxToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValue = expectedValueLink +
            (valueOfOneSnx * amountSnx) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValue);
    }

    function testReturnUsdValueEthLinkSnx(
        uint128 amountEth,
        uint128 amountLink,
        uint128 amountSnx
    ) public {
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedValueEth = (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValueEth);

        uint256 valueOfOneLink = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValueLink = (valueOfOneLink * amountLink) /
            10**Constants.linkDecimals;
        depositERC20InVault(link, amountLink, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValueEth + expectedValueLink);

        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth * rateEthToUsd) /
            10 **
                (Constants.oracleSnxToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueSnx = (valueOfOneSnx * amountSnx) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(
            actualValue,
            expectedValueEth + expectedValueLink + expectedValueSnx
        );
    }

    function testReturnUsdValueSnxEthSnx(
        uint128 amountSnx1,
        uint128 amountSnx2,
        uint128 amountEth
    ) public {
        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth * rateEthToUsd) /
            10 **
                (Constants.oracleSnxToEthDecimals +
                    Constants.oracleEthToUsdDecimals);
        uint256 expectedValueSnx1 = (valueOfOneSnx * amountSnx1) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx1, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValueSnx1);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedValueEth = (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(actualValue, expectedValueSnx1 + expectedValueEth);

        uint256 expectedValueSnx2 = (valueOfOneSnx * amountSnx2) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx2, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));
        assertEq(
            actualValue,
            expectedValueSnx1 + expectedValueEth + expectedValueSnx2
        );
    }

    function testReturnEthValueEthEth(uint128 amountEth1, uint128 amountEth2)
        public
    {
        uint256 valueOfOneEth = Constants.WAD;
        uint256 expectedValueEth1 = (valueOfOneEth * amountEth1) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth1, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueEth1);

        uint256 expectedValueEth2 = (valueOfOneEth * amountEth2) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth2, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueEth1 + expectedValueEth2);
    }

    function testReturnEthValueEthLink(uint128 amountEth, uint128 amountLink)
        public
    {
        uint256 valueOfOneEth = Constants.WAD;
        uint256 expectedValueEth = (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;
        depositERC20InVault(eth, amountEth, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueEth);

        uint256 valueOfOneLinkInUsd = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValueLink = (((valueOfOneLinkInUsd * amountLink) /
            10**Constants.linkDecimals) *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;
        depositERC20InVault(link, amountLink, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueEth + expectedValueLink);
    }

    function testReturnEthValueSnxLink(uint128 amountSnx, uint128 amountLink)
        public
    {
        uint256 valueOfOneSnx = (Constants.WAD * rateSnxToEth) /
            10**Constants.oracleSnxToEthDecimals;
        uint256 expectedValueSnx = (valueOfOneSnx * amountSnx) /
            10**Constants.snxDecimals;
        depositERC20InVault(snx, amountSnx, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueSnx);

        uint256 valueOfOneLinkInUsd = (Constants.WAD * rateLinkToUsd) /
            10**Constants.oracleLinkToUsdDecimals;
        uint256 expectedValueLink = (((valueOfOneLinkInUsd * amountLink) /
            10**Constants.linkDecimals) *
            10**Constants.oracleEthToUsdDecimals) / rateEthToUsd;
        depositERC20InVault(link, amountLink, vaultOwner);
        actualValue = proxy.getValue(uint8(Constants.EthNumeraire));
        assertEq(actualValue, expectedValueSnx + expectedValueLink);
    }

    function testNumeraireOfEthVault() public {
        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)",
                        block.timestamp,
                        block.number + 1000,
                        blockhash(block.number)
                    )
                )
            ),
            Constants.EthNumeraire
        );
        Vault proxyVault = Vault(proxyAddr);

        (,,,,, uint8 num) = proxyVault.debt();

        assertTrue(uint256(num) == Constants.EthNumeraire);

    }

    function testReturnUsdValueEthPriceChange(
        uint128 amountEth,
        uint256 newRateEthToUsd
    ) public {
        vm.assume(newRateEthToUsd <= uint256(type(int256).max));
        vm.assume(newRateEthToUsd <= type(uint256).max / (10**18));
        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newRateEthToUsd));

        uint256 valueOfOneEth = (Constants.WAD * newRateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        if (valueOfOneEth != 0) {
            vm.assume(amountEth < type(uint256).max / valueOfOneEth);
        }
        uint256 expectedValue = (valueOfOneEth * amountEth) /
            10**Constants.ethDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testAmountOfAllowedCredit(uint128 amountEth) public {
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);
        (, uint16 _collThres, , , , ) = proxy.debt();

        uint256 expectedValue = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        uint256 actualValue = proxy.getRemainingCredit();

        assertEq(actualValue, expectedValue);
    }

    function testAllowCreditAfterDeposit(
        uint128 amountEth,
        uint128 amountCredit
    ) public {
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(uint256(amountCredit) * _collThres < type(uint128).max);
        //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), vaultOwner, amountCredit);
        proxy.takeCredit(amountCredit);
        vm.stopPrank();

        assertEq(stable.balanceOf(vaultOwner), amountCredit);
    }

    function testNotAllowTooMuchCreditAfterDeposit(
        uint128 amountEth,
        uint128 amountCredit
    ) public {
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(uint256(amountCredit) * _collThres < type(uint128).max);
        //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit > maxCredit);

        vm.startPrank(vaultOwner);
        vm.expectRevert("Cannot take this amount of extra credit!");
        proxy.takeCredit(amountCredit);
        vm.stopPrank();

        assertEq(stable.balanceOf(vaultOwner), 0);
    }

    function testIncreaseOfDebtPerBlock(
        uint128 amountEth,
        uint128 amountCredit,
        uint32 amountOfBlocksToRoll
    ) public {
        (, , , uint64 _yearlyInterestRate, , ) = proxy.debt();
        uint128 base = 1e18 + 5e16;
        //1 + r expressed as 18 decimals fixed point number
        uint128 exponent = (uint128(amountOfBlocksToRoll) * 1e18) /
            uint128(proxy.yearlyBlocks());
        vm.assume(
            amountCredit < type(uint128).max / LogExpMath.pow(base, exponent)
        );

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);
        (, uint16 _collThres, , , , ) = proxy.debt();

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), vaultOwner, amountCredit);
        proxy.takeCredit(amountCredit);
        vm.stopPrank();

        (, , , _yearlyInterestRate, , ) = proxy.debt();
        base = 1e18 + _yearlyInterestRate;

        uint256 debtAtStart = proxy.getOpenDebt();

        vm.roll(block.number + amountOfBlocksToRoll);

        uint256 actualDebt = proxy.getOpenDebt();

        uint128 expectedDebt = uint128(
            (debtAtStart *
                (
                    LogExpMath.pow(
                        _yearlyInterestRate + 10**18,
                        (uint256(amountOfBlocksToRoll) * 10**18) /
                            proxy.yearlyBlocks()
                    )
                )) / 10**18
        );

        assertEq(actualDebt, expectedDebt);
    }

    function testNotAllowCreditAfterLargeUnrealizedDebt(uint128 amountEth)
        public
    {
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(uint256(amountEth) * _collThres < type(uint128).max);
        //prevent overflow in takecredit with absurd values
        vm.assume(amountEth > 1e15);
        uint128 valueOfOneEth = uint128(
            (Constants.WAD * rateEthToUsd) /
                10**Constants.oracleEthToUsdDecimals
        );
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint128 amountCredit = uint128(
            (((valueOfOneEth * amountEth) / 10**Constants.ethDecimals) * 100) /
                _collThres
        ) - 1;

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        proxy.takeCredit(amountCredit);
        vm.stopPrank();

        vm.roll(block.number + 10);
        //

        vm.startPrank(vaultOwner);
        vm.expectRevert("Cannot take this amount of extra credit!");
        proxy.takeCredit(1);
        vm.stopPrank();
    }

    function testAllowAdditionalCreditAfterPriceIncrease(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 newPrice
    ) public {
        vm.assume(
            newPrice * 10**Constants.oracleEthToUsdDecimals > rateEthToUsd
        );
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);
        //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = uint128(
            (Constants.WAD * rateEthToUsd) /
                10**Constants.oracleEthToUsdDecimals
        );

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(vaultOwner);
        proxy.takeCredit(amountCredit);
        vm.stopPrank();

        vm.prank(oracleOwner);
        uint256 newRateEthToUsd = newPrice *
            10**Constants.oracleEthToUsdDecimals;
        oracleEthToUsd.transmit(int192(int256(newRateEthToUsd)));

        uint256 newValueOfOneEth = (Constants.WAD * newRateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        uint256 expectedAvailableCredit = (((newValueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) /
            _collThres -
            amountCredit;

        uint256 actualAvailableCredit = proxy.getRemainingCredit();

        assertEq(actualAvailableCredit, expectedAvailableCredit);
        //no blocks pass in foundry
    }

    function testNotAllowWithdrawalIfOpenDebtIsTooLarge(
        uint128 amountEth,
        uint128 amountEthWithdrawal
    ) public {
        vm.assume(amountEth > 0 && amountEthWithdrawal > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);
        vm.assume(amountEth >= amountEthWithdrawal);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        emit log_named_uint("valueOfOneEth", valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getRemainingCredit() - 1);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        assetAmounts[0] = amountEthWithdrawal;
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W: coll. value too low!");
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testAllowWithdrawalIfOpenDebtIsNotTooLarge(
        uint128 amountEth,
        uint128 amountEthWithdrawal,
        uint128 amountCredit
    ) public {
        vm.assume(amountEth > 0 && amountEthWithdrawal > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);
        vm.assume(amountEth >= amountEthWithdrawal);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);
        emit log_named_uint("valueOfOneEth", valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        vm.assume(
            proxy.getRemainingCredit() >
                ((amountEthWithdrawal * valueOfOneEth) /
                    10**Constants.ethDecimals) +
                    amountCredit
        );

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        assetAmounts[0] = amountEthWithdrawal;
        vm.startPrank(vaultOwner);
        proxy.getRemainingCredit();
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testIncreaseBalanceStakeContractSyncDebt(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 blocksToRoll
    ) public {
        vm.assume(amountEth > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        (, , , uint64 _yearlyInterestRate, , ) = proxy.debt();

        uint256 balanceBefore = stable.balanceOf(stakeContract);

        vm.roll(block.number + blocksToRoll);
        proxy.syncDebt();
        uint256 balanceAfter = stable.balanceOf(stakeContract);

        uint128 base = _yearlyInterestRate + 10**18;
        uint128 exponent = uint128(
            (uint128(blocksToRoll) * 10**18) / proxy.yearlyBlocks()
        );
        uint128 expectedDebt = uint128(
            (amountCredit * (LogExpMath.pow(base, exponent))) / 10**18
        );
        uint128 unrealisedDebt = expectedDebt - amountCredit;

        assertEq(unrealisedDebt, balanceAfter - balanceBefore);
    }

    function testRepayExactDebt(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 blocksToRoll
    ) public {
        vm.assume(amountEth > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(tokenCreatorAddress);
        stable.transfer(vaultOwner, 1000 * 10**18);

        vm.roll(block.number + blocksToRoll);

        uint128 openDebt = proxy.getOpenDebt();
        vm.startPrank(address(proxy));
        stable.mint(
            vaultOwner,
            openDebt > stable.balanceOf(vaultOwner)
                ? openDebt - stable.balanceOf(vaultOwner)
                : 0
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        proxy.repayDebt(openDebt);

        assertEq(proxy.getOpenDebt(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxy.getOpenDebt(), 0);
    }

    function testRepayExessiveDebt(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 blocksToRoll,
        uint8 factor
    ) public {
        vm.assume(amountEth > 0);
        vm.assume(factor > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(address(proxy));
        stable.mint(vaultOwner, factor * amountCredit);

        vm.roll(block.number + blocksToRoll);

        uint128 openDebt = proxy.getOpenDebt();
        uint256 balanceBefore = stable.balanceOf(vaultOwner);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(proxy), address(0), openDebt);
        proxy.repayDebt(openDebt * factor);
        vm.stopPrank();

        uint256 balanceAfter = stable.balanceOf(vaultOwner);

        assertEq(balanceBefore - openDebt, balanceAfter);
        assertEq(proxy.getOpenDebt(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxy.getOpenDebt(), 0);
    }

    function testRepayPartialDebt(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 blocksToRoll,
        uint128 toRepay
    ) public {
        // vm.assume(amountEth > 1e15 && amountCredit > 1e15 && blocksToRoll > 1000 && toRepay > 0);
        vm.assume(amountEth > 0);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(amountEth < type(uint128).max / _collThres);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) /
            10**Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (((valueOfOneEth * amountEth) /
            10**Constants.ethDecimals) * 100) / _collThres;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.prank(address(proxy));
        stable.mint(vaultOwner, 1000 * 10**18);

        vm.roll(block.number + blocksToRoll);

        uint128 openDebt = proxy.getOpenDebt();
        vm.assume(toRepay < openDebt);

        vm.prank(vaultOwner);
        proxy.repayDebt(toRepay);
        (, , , uint64 _yearlyInterestRate, , ) = proxy.debt();
        uint128 base = _yearlyInterestRate + 10**18;
        uint128 exponent = uint128(
            (uint128(blocksToRoll) * 10**18) / proxy.yearlyBlocks()
        );
        uint128 expectedDebt = uint128(
            (amountCredit * (LogExpMath.pow(base, exponent))) / 10**18
        ) - toRepay;

        assertEq(proxy.getOpenDebt(), expectedDebt);

        vm.roll(block.number + uint256(blocksToRoll));
        (, , , _yearlyInterestRate, , ) = proxy.debt();
        base = _yearlyInterestRate + 10**18;
        exponent = uint128(
            (uint128(blocksToRoll) * 10**18) / proxy.yearlyBlocks()
        );
        expectedDebt = uint128(
            (expectedDebt * (LogExpMath.pow(base, exponent))) / 10**18
        );

        assertEq(proxy.getOpenDebt(), expectedDebt);
    }

    function sumElementsOfList(uint128[] memory _data)
        public
        payable
        returns (uint256 sum)
    {
        //cache
        uint256 len = _data.length;

        for (uint256 i = 0; i < len; ) {
            // optimizooooor
            assembly {
                sum := add(sum, mload(add(add(_data, 0x20), mul(i, 0x20))))
            }

            // iykyk
            unchecked {
                ++i;
            }
        }
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
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC721InVault(
        ERC721Mock token,
        uint128[] memory tokenIds,
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
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC1155InVault(
        ERC1155Mock token,
        uint256 tokenId,
        uint256 amount,
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
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetTypes = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;
        assetTypes[0] = 2;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }
}
