// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/UniswapV2FactoryMock.sol";
import "../mockups/UniswapV2PairMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/StandardERC20SubRegistry.sol";
import "../AssetRegistry/UniswapV2SubRegistry.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract UniswapV2SubRegistryTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    ERC20Mock private snx;
    ERC20Mock private safemoon;

    UniswapV2FactoryMock private uniswapV2Factory;
    UniswapV2PairMock private uniswapV2Pair;
    UniswapV2PairMock private pairSnxEth;
    UniswapV2PairMock private pairSafemoonEth;

    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleSnxToEth;

    UniswapV2PairMock private uniV2SnxEth;

    StandardERC20Registry private standardERC20Registry;
    UniswapV2SubRegistry private uniswapV2SubRegistry;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);
    address private haydenAdams = address(4);
    address private lpProvider = address(5);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;
    uint256 rateSnxToEth = 16 * 10**(Constants.oracleSnxToEthDecimals - 4);

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);

    uint256[] emptyList = new uint256[](0);

    uint256 usdValue = 10 ** 6 * FixedPointMathLib.WAD;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        safemoon = new ERC20Mock(
            "Safemoon Mock",
            "mSFMN",
            uint8(Constants.safemoonDecimals)
        );
        vm.stopPrank();

        vm.startPrank(haydenAdams);
        uniswapV2Factory = new UniswapV2FactoryMock();
        uniswapV2Pair = new UniswapV2PairMock();
        address pairSnxEthAddr = uniswapV2Factory.createPair(address(snx), address(eth));
        pairSnxEth = UniswapV2PairMock(pairSnxEthAddr);
        address pairSafemoonEthAddr = uniswapV2Factory.createPair(address(safemoon), address(eth));
        pairSafemoonEth = UniswapV2PairMock(pairSafemoonEthAddr);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWmaycToUsdDecimals),
            "SNX / ETH",
            rateSnxToEth
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
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        vm.stopPrank();

        oracleEthToUsdArr[0] = address(oracleEthToUsd);

        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);

        vm.startPrank(creatorAddress);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: 0x0000000000000000000000000000000000000000,
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );

        standardERC20Registry = new StandardERC20Registry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
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
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );

        uniswapV2SubRegistry = new UniswapV2SubRegistry(
            address(mainRegistry),
            address(oracleHub),
            address(uniswapV2Factory)
        );
        mainRegistry.addSubRegistry(address(uniswapV2SubRegistry));
        vm.stopPrank();
    }

    //this is a before each
    function setUp() public {

    }

    //Test Mocked Contracts
    function testReserves() public {
        vm.startPrank(tokenCreatorAddress);
        pairSnxEth.mint(
            tokenCreatorAddress, 
            calcAmountFromUsdValue(address(snx), usdValue), 
            calcAmountFromUsdValue(address(eth), usdValue)
        );
        vm.stopPrank();

        (uint112 reserve0, uint112 reserve1, ) = pairSnxEth.getReserves();

        address[] memory addressArr = new address[](2);
        addressArr[0] = address(snx);
        addressArr[1] = address(eth);
        uint256[] memory amountArr = new uint256[](2);
        amountArr[0] = uint256(reserve0);
        amountArr[1] = uint256(reserve1);

        uint256[] memory values = mainRegistry.getListOfValuesPerAsset(addressArr, new uint256[](2), amountArr, Constants.UsdNumeraire);

        inRange(values[0], usdValue);
        inRange(values[1], usdValue);
    }

    function testReserves2() public {
        vm.startPrank(tokenCreatorAddress);
        pairSnxEth.mint(
            tokenCreatorAddress, 
            10 ** Constants.snxDecimals, 
            10 ** Constants.ethDecimals * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals
        );
        vm.stopPrank();

        (uint112 reserve0, uint112 reserve1, ) = pairSnxEth.getReserves();

        address[] memory addressArr = new address[](2);
        addressArr[0] = address(snx);
        addressArr[1] = address(eth);
        uint256[] memory amountArr = new uint256[](2);
        amountArr[0] = uint256(reserve0);
        amountArr[1] = uint256(reserve1);

        uint256[] memory values = mainRegistry.getListOfValuesPerAsset(addressArr, new uint256[](2), amountArr, Constants.UsdNumeraire);

        assertEq(values[0], values[1]);
    }

    //Test setAssetInformation
    function testNonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithNonWhiteListedUnderlyingAsset() public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("UV2_SAI: NOT_WHITELISTED");
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSafemoonEth),
            emptyList
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            assetCreditRatings
        );
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();

        assertTrue(uniswapV2SubRegistry.inSubRegistry(address(pairSnxEth)));
    }

    function testOwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](2);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            assetCreditRatings
        );
        vm.stopPrank();

        assertTrue(uniswapV2SubRegistry.inSubRegistry(address(pairSnxEth)));
    }

    function testOwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();

        assertTrue(uniswapV2SubRegistry.inSubRegistry(address(pairSnxEth)));
    }

    //Test isWhiteListed
    function testIsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();

        assertTrue(uniswapV2SubRegistry.isWhiteListed(address(pairSnxEth), 0));
    }

    function testIsWhitelistedNegative(address randomAsset) public {
        assertTrue(!uniswapV2SubRegistry.isWhiteListed(randomAsset, 0));
    }

    //Test getValue 
    function testReturnValueFromBalancedPair(uint112 amountSnx)
        public
    {
        vm.assume(amountSnx < 10**29);
        vm.startPrank(creatorAddress);
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();
        pairSnxEth.mint(
            tokenCreatorAddress, 
            10 ** Constants.snxDecimals, 
            10 ** Constants.ethDecimals * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals
        ); //Initiate pool

        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth <= uint256(type(uint112).max));
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());

        pairSnxEth.mint(
            lpProvider, 
            amountSnx, 
            amountEth
        );

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10**Constants.oracleSnxToEthDecimals * amountSnx / 10**Constants.snxDecimals;
        uint256 expectedValueInNumeraire = 2 * valueSnx;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(pairSnxEth),
                assetId: 0,
                assetAmount: pairSnxEth.balanceOf(lpProvider),
                numeraire: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInNumeraire
        ) = uniswapV2SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        inRange(actualValueInNumeraire, expectedValueInNumeraire);
    }

    function testReturnValueFromBalancedPair2()
        public
    {
        vm.startPrank(creatorAddress);
        uniswapV2SubRegistry.setAssetInformation(
            address(pairSnxEth),
            emptyList
        );
        vm.stopPrank();
        pairSnxEth.mint(
            tokenCreatorAddress, 
            10 ** Constants.snxDecimals, 
            10 ** Constants.ethDecimals * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals
        ); //Initiate pool

        uint112 amountSnx = 672542079414564404298816125000;
        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth <= uint256(type(uint112).max));
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth > 100000000000);

        pairSnxEth.mint(
            lpProvider, 
            amountSnx, 
            amountEth
        );

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10**Constants.oracleSnxToEthDecimals * amountSnx / 10**Constants.snxDecimals;
        uint256 expectedValueInNumeraire = 2 * valueSnx;

        SubRegistry.GetValueInput memory getValueInput = SubRegistry
            .GetValueInput({
                assetAddress: address(pairSnxEth),
                assetId: 0,
                assetAmount: pairSnxEth.balanceOf(lpProvider),
                numeraire: 1
            });
        (
            uint256 actualValueInUsd,
            uint256 actualValueInNumeraire
        ) = uniswapV2SubRegistry.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        inRange(actualValueInNumeraire, expectedValueInNumeraire);
    }

    //Helper Functions
    function calcAmountFromUsdValue(address token, uint256 UsdValue) internal returns(uint256 amount) {
        address[] memory addressArr = new address[](1);
        uint256[] memory idArr = new uint256[](1);
        uint256[] memory amountArr = new uint256[](1);

        addressArr[0] = token;
        idArr[0] = 0;
        amountArr[0] = 10 ** ERC20Mock(token).decimals();

        uint256 rateTokenToUsd = mainRegistry.getTotalValue(
            addressArr,
            idArr,
            amountArr,
            0
        );
        amount = FixedPointMathLib.mulDivUp(
            UsdValue,
            amountArr[0],
            rateTokenToUsd
        );
    }

    function inRange(uint256 expectedValue, uint256 actualvalue) internal {
        assertGe(expectedValue * 100000001 / 100000000,  actualvalue);
        assertLe(expectedValue * 99999999 / 100000000,  actualvalue);
    }
}
