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

    function testReserves() public {
        vm.startPrank(tokenCreatorAddress);
        pairSnxEth.mint(
            lpProvider, 
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

        assertEqDecimal(values[0], usdValue, 18);
        assertEqDecimal(values[1], usdValue, 18);
    }

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
}
