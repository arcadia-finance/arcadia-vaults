/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/UniswapV2FactoryMock.sol";
import "../mockups/UniswapV2PairMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/StandardERC20PricingModule.sol";
import "../AssetRegistry/UniswapV2PricingModule.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../mockups/ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract UniswapV2PricingModuleExtension is UniswapV2PricingModule {
    constructor(address _mainRegistry, address _oracleHub, address _uniswapV2Factory, address _erc20PricingModule)
        UniswapV2PricingModule(_mainRegistry, _oracleHub, _uniswapV2Factory, _erc20PricingModule)
    {}

    function getTrustedTokenAmounts(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) =
            _getTrustedTokenAmounts(pair, trustedPriceToken0, trustedPriceToken1, liquidityAmount);
    }

    function getTrustedReserves(address pair, uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        public
        view
        returns (uint256 reserve0, uint256 reserve1)
    {
        (reserve0, reserve1) = _getTrustedReserves(pair, trustedPriceToken0, trustedPriceToken1);
    }

    function computeProfitMaximizingTrade(
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 reserve0,
        uint256 reserve1
    ) public pure returns (bool token0ToToken1, uint256 amountIn) {
        (token0ToToken1, amountIn) =
            _computeProfitMaximizingTrade(trustedPriceToken0, trustedPriceToken1, reserve0, reserve1);
    }

    function computeTokenAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 kLast
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) = _computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
    }
}

abstract contract UniswapV2PricingModuleTest is Test {
    using stdStorage for StdStorage;

    OracleHub public oracleHub;
    MainRegistry public mainRegistry;

    ERC20Mock public dai;
    ERC20Mock public eth;
    ERC20Mock public snx;
    ERC20Mock public safemoon;

    UniswapV2FactoryMock public uniswapV2Factory;
    UniswapV2PairMock public uniswapV2Pair;
    UniswapV2PairMock public pairSnxEth;
    UniswapV2PairMock public pairSafemoonEth;

    ArcadiaOracle public oracleDaiToUsd;
    ArcadiaOracle public oracleEthToUsd;
    ArcadiaOracle public oracleSnxToEth;
    ArcadiaOracle public oracleSnxToUsd;

    StandardERC20PricingModule public standardERC20PricingModule;
    UniswapV2PricingModuleExtension public uniswapV2PricingModule;

    address public creatorAddress = address(1);
    address public tokenCreatorAddress = address(2);
    address public oracleOwner = address(3);
    address public haydenAdams = address(4);
    address public lpProvider = address(5);

    uint256 public rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
    uint256 public rateEthToUsd = 3000 * 10 ** Constants.oracleEthToUsdDecimals;
    uint256 public rateSnxToEth = 16 * 10 ** (Constants.oracleSnxToEthDecimals - 4);

    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleSnxToEthEthToUsd = new address[](2);
    address[] public oracleSnxToUsdArr = new address[](1);

    uint256[] emptyList = new uint256[](0);
    uint16[] emptyListUint16 = new uint16[](0);

    uint256 usdValue = 10 ** 6 * FixedPointMathLib.WAD;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
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
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleDaiToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD", rateDaiToUsd);
        oracleEthToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD", rateEthToUsd);
        oracleSnxToEth =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleSnxToEthDecimals), "SNX / ETH", rateSnxToEth);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetBaseCurrency: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        oracleDaiToUsdArr[0] = address(oracleDaiToUsd);

        oracleEthToUsdArr[0] = address(oracleEthToUsd);

        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );

        uniswapV2PricingModule = new UniswapV2PricingModuleExtension(
            address(mainRegistry),
            address(oracleHub),
            address(uniswapV2Factory),
            address(standardERC20PricingModule)
        );
        mainRegistry.addPricingModule(address(uniswapV2PricingModule));
        vm.stopPrank();
    }

    //this is a before each
    function setUp() public virtual {}
}

contract OldTests is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    //Test getValue
    function xtestReturnValueInUsdFromBalancedPair(uint112 amountSnx) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(amountSnx < type(uint112).max - reserve0);
        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth < type(uint112).max - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth >= 10000); //For smaller amounts precision is to low (since uniswap will calculate share of tokens as relative share with totalsupply -> loose least significant digits)

        pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals * rateEthToUsd
            / 10 ** Constants.oracleEthToUsdDecimals * amountSnx / 10 ** Constants.snxDecimals;
        uint256 valueEth = Constants.WAD * rateEthToUsd / 10 ** Constants.oracleEthToUsdDecimals * amountEth
            / 10 ** Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = valueSnx + valueEth;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: pairSnxEth.balanceOf(lpProvider),
            baseCurrency: Constants.UsdBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        assertInRange(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function xtestReturnValueInEthFromBalancedPair(uint112 amountSnx) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(amountSnx < type(uint112).max - reserve0);
        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth < type(uint112).max - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth >= 10000); //For smaller amounts precision is to low (since uniswap will calculate share of tokens as relative share with totalsupply -> loose least significant digits)

        pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals * amountSnx
            / 10 ** Constants.snxDecimals;
        uint256 valueEth = Constants.WAD * amountEth / 10 ** Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = valueSnx + valueEth;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: pairSnxEth.balanceOf(lpProvider),
            baseCurrency: Constants.EthBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        assertInRange(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function xtestReturnValueInEthFromUnbalancedPair(uint112 amountSnx, uint112 amountEthSwapped) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(amountSnx < uint256(type(uint112).max) - reserve0);
        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth < uint256(type(uint112).max) - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth >= 10000); //For smaller amounts precision is to low (since uniswap will calculate share of tokens as relative share with totalsupply -> loose least significant digits)

        uint256 lpAmount = pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        (reserve0, reserve1,) = pairSnxEth.getReserves();
        vm.assume(reserve0 > pairSnxEth.getAmountOut(amountEthSwapped, reserve1, reserve0));
        vm.assume(amountEthSwapped < uint256(type(uint112).max) - reserve1);
        uint256 lpGrowth = pairSnxEth.swapToken1ToToken0(amountEthSwapped);

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals * amountSnx
            / 10 ** Constants.snxDecimals;
        uint256 valueEth = Constants.WAD * amountEth / 10 ** Constants.ethDecimals;
        //For approximation hereunder to hold the imbalance can't be to big, for bigger imbalances, the LP-value will always be underestimated -> no risk for protocol (see next test)
        vm.assume(amountEthSwapped < uint256(reserve1) * 10000000000);
        uint256 expectedValueInBaseCurrency = (valueSnx + valueEth) * lpGrowth ** 2 / FixedPointMathLib.WAD ** 2; //Approximation, we do two swaps of almost equal size -> lp-position acrues fees

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: lpAmount,
            baseCurrency: Constants.EthBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        assertInRange(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function xtestReturnValueInEthFromVeryUnbalancedPair(uint112 amountSnx, uint112 amountEthSwapped) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(amountSnx < uint256(type(uint112).max) - reserve0);
        uint256 amountEth = amountSnx * rateSnxToEth * 10 ** Constants.ethDecimals
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);
        vm.assume(amountEth < uint256(type(uint112).max) - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth >= 10000); //For smaller amounts precision is to low (since uniswap will calculate share of tokens as relative share with totalsupply -> loose least significant digits)

        uint256 lpAmount = pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        (reserve0, reserve1,) = pairSnxEth.getReserves();
        vm.assume(reserve0 > pairSnxEth.getAmountOut(amountEthSwapped, reserve1, reserve0));
        vm.assume(amountEthSwapped < uint256(type(uint112).max) - reserve1);
        uint256 lpGrowth = pairSnxEth.swapToken1ToToken0(amountEthSwapped);

        uint256 valueSnx = Constants.WAD * rateSnxToEth / 10 ** Constants.oracleSnxToEthDecimals * amountSnx
            / 10 ** Constants.snxDecimals;
        uint256 valueEth = Constants.WAD * amountEth / 10 ** Constants.ethDecimals;
        //for very big imbalances, the LP-value will always be underestimated -> no risk for protocol (see next test)
        vm.assume(amountEthSwapped > uint256(reserve1) * 10000000000);
        uint256 expectedValueInBaseCurrency = (valueSnx + valueEth) * lpGrowth ** 2 / FixedPointMathLib.WAD ** 2; //Approximation, we do two swaps of almost equal size -> lp-position acrues fees

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: lpAmount,
            baseCurrency: Constants.EthBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        //for very big imbalances, the LP-value will always be underestimated -> no risk for protocol (see next test)
        assertLe(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueFromBalancedPair(
        uint112 amountSnx,
        uint8 _ethDecimals,
        uint8 _snxDecimals,
        uint8 _oracleEthToUsdDecimals,
        uint8 _oracleSnxToUsdDecimals,
        uint64 _rateEthToUsd,
        uint64 _rateSnxToUsd
    ) public {
        vm.assume(_ethDecimals <= 18);
        vm.assume(_snxDecimals <= 18);
        vm.assume(_oracleEthToUsdDecimals <= 18);
        vm.assume(_oracleSnxToUsdDecimals <= 18);
        vm.assume(_rateEthToUsd > 0);
        vm.assume(_rateSnxToUsd > 0);

        //Redeploy tokens with different number of decimals
        eth = new ERC20Mock("ETH Mock", "mETH", _ethDecimals);
        snx = new ERC20Mock("SNX Mock", "mSNX", _snxDecimals);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));

        {
            // Avoid Stack too deep
            uint256 amount0 = 10 ** _snxDecimals;
            uint256 amount1 = uint256(_rateSnxToUsd) * 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
                / (_rateEthToUsd * 10 ** _oracleSnxToUsdDecimals);
            vm.assume(amount1 / _rateEthToUsd > 0);
            vm.assume(amount1 < uint256(type(uint112).max));
            vm.assume(amount0 * amount1 > pairSnxEth.MINIMUM_LIQUIDITY() + 1);
            pairSnxEth.mint(tokenCreatorAddress, amount0, amount1);
        }

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(
            uint256(amountSnx) * uint256(_rateSnxToUsd)
                < type(uint256).max / 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
        );
        uint256 amountEth = uint256(amountSnx) * uint256(_rateSnxToUsd) * 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
            / (_rateEthToUsd * 10 ** (_snxDecimals + _oracleSnxToUsdDecimals));
        vm.assume(amountSnx < type(uint112).max - reserve0);
        vm.assume(amountEth < type(uint112).max - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountEth >= 10000);
        vm.assume(amountSnx >= 10000);
        vm.assume(
            FixedPointMathLib.WAD * (_rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals)
                * (FixedPointMathLib.WAD / 10 ** _snxDecimals) < type(uint256).max / (reserve0 + amountSnx)
        );

        //Redeploy oracles with new decimals
        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(0, "ETH / USD", _rateEthToUsd);
        oracleSnxToUsd = arcadiaOracleFixture.initMockedOracle(0, "SNX / USD", _rateSnxToUsd);
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** _oracleEthToUsdDecimals),
                baseAssetBaseCurrency: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** _oracleSnxToUsdDecimals),
                baseAssetBaseCurrency: 0,
                quoteAsset: "SNX",
                baseAsset: "USD",
                oracleAddress: address(oracleSnxToUsd),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        oracleSnxToUsdArr[0] = address(oracleSnxToUsd);

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** _ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToUsdArr,
                assetUnit: uint64(10 ** _snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        uint256 amount = pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        vm.assume(Constants.WAD * _rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals < type(uint256).max / amountSnx);
        vm.assume(Constants.WAD * _rateEthToUsd / 10 ** _oracleEthToUsdDecimals < type(uint256).max / amountEth);
        uint256 valueSnx =
            Constants.WAD * _rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals * amountSnx / 10 ** _snxDecimals;
        uint256 valueEth =
            Constants.WAD * _rateEthToUsd / 10 ** _oracleEthToUsdDecimals * amountEth / 10 ** _ethDecimals;
        uint256 expectedValueInUsd = valueSnx + valueEth;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: amount,
            baseCurrency: Constants.UsdBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertInRange(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, 0);
    }

    function xtestReturnValueFromBalancedPairOverflow(uint112 amountSnx, uint64 _rateEthToUsd, uint128 _rateSnxToUsd)
        public
    {
        vm.assume(_rateEthToUsd > 0);
        vm.assume(_rateSnxToUsd > 0);
        uint8 _ethDecimals = 0;
        uint8 _snxDecimals = 0;
        uint8 _oracleEthToUsdDecimals = 0;
        uint8 _oracleSnxToUsdDecimals = 0;

        eth = new ERC20Mock("ETH Mock", "mETH", _ethDecimals);
        snx = new ERC20Mock("SNX Mock", "mSNX", _snxDecimals);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));

        {
            // Avoid Stack too deep
            uint256 amount0 = 10 ** _snxDecimals;
            uint256 amount1 = 10 ** (_ethDecimals + _oracleEthToUsdDecimals) * _rateSnxToUsd
                / (_rateEthToUsd * 10 ** _oracleSnxToUsdDecimals);
            vm.assume(amount1 / _rateEthToUsd > 0);
            vm.assume(amount1 <= uint256(type(uint112).max));
            vm.assume(amount0 * amount1 > pairSnxEth.MINIMUM_LIQUIDITY() + 1);
            pairSnxEth.mint(tokenCreatorAddress, amount0, amount1);
        }

        (uint112 reserve0, uint112 reserve1,) = pairSnxEth.getReserves();
        vm.assume(
            uint256(amountSnx) * uint256(_rateSnxToUsd)
                < type(uint256).max / 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
        );
        uint256 amountEth = uint256(amountSnx) * uint256(_rateSnxToUsd) * 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
            / (_rateEthToUsd * 10 ** (_snxDecimals + _oracleSnxToUsdDecimals));
        vm.assume(amountSnx < uint256(type(uint112).max) - reserve0);
        vm.assume(amountEth < uint256(type(uint112).max) - reserve1);
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY());
        vm.assume(amountSnx >= 10);
        vm.assume(
            FixedPointMathLib.WAD * (_rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals)
                * (FixedPointMathLib.WAD / 10 ** _snxDecimals) >= type(uint256).max / (reserve0 + amountSnx)
        );

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(0, "ETH / USD", _rateEthToUsd);
        oracleSnxToUsd = arcadiaOracleFixture.initMockedOracle(0, "SNX / USD", _rateSnxToUsd);
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** _oracleEthToUsdDecimals),
                baseAssetBaseCurrency: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** _oracleSnxToUsdDecimals),
                baseAssetBaseCurrency: 0,
                quoteAsset: "SNX",
                baseAsset: "USD",
                oracleAddress: address(oracleSnxToUsd),
                quoteAssetAddress: address(snx),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        oracleSnxToUsdArr[0] = address(oracleSnxToUsd);

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** _ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToUsdArr,
                assetUnit: uint64(10 ** _snxDecimals),
                assetAddress: address(snx)
            }),
            emptyListUint16,
            emptyListUint16
        );
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        uint256 amount = pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: amount,
            baseCurrency: Constants.UsdBaseCurrency
        });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        uniswapV2PricingModule.getValue(getValueInput);
    }

    //Helper Functions

    function assertInRange(uint256 actualValue, uint256 expectedValue) internal {
        assertGe(actualValue * 10003 / 10000, expectedValue);
        assertLe(actualValue * 9997 / 10000, expectedValue);
    }
}

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
//////////////////////////////////////////////////////////////*/
contract DeploymentTest is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        assertEq(uniswapV2PricingModule.mainRegistry(), address(mainRegistry));
        assertEq(uniswapV2PricingModule.oracleHub(), address(oracleHub));
        assertEq(uniswapV2PricingModule.uniswapV2Factory(), address(uniswapV2Factory));
    }
}

/*///////////////////////////////////////////////////////////////
                    UNISWAP V2 FEE
///////////////////////////////////////////////////////////////*/
contract UniswapV2Fees is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_syncFee_FeeOffToFeeOff(address sender) public {
        //Given: feeOn is false
        assertTrue(!uniswapV2PricingModule.feeOn());
        //And: feeTo on the UniswapV2 factory is the zero-address (fees are off)
        assertEq(uniswapV2Factory.feeTo(), address(0));

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2PricingModule.syncFee();

        //Then: feeOn is false
        assertTrue(!uniswapV2PricingModule.feeOn());
    }

    function testSuccess_syncFee_FeeOffToFeeOn(address sender, address feeTo) public {
        //Given: feeOn is false
        assertTrue(!uniswapV2PricingModule.feeOn());
        //And: feeTo on the UniswapV2 factory is not the zero-address (fees are on)
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2PricingModule.syncFee();

        //Then: feeOn is true
        assertTrue(uniswapV2PricingModule.feeOn());
    }

    function testSuccess_syncFee_FeeOnToFeeOn(address sender, address feeTo) public {
        //Given: feeTo on the UniswapV2 factory is not the zero-address (fees are on)
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);
        //And: feeOn is true
        uniswapV2PricingModule.syncFee();
        assertTrue(uniswapV2PricingModule.feeOn());

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2PricingModule.syncFee();

        //Then: feeOn is true
        assertTrue(uniswapV2PricingModule.feeOn());
    }

    function testSuccess_syncFee_FeeOnToFeeOff(address sender, address feeTo) public {
        //Given: feeOn is true
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);
        uniswapV2PricingModule.syncFee();
        assertTrue(uniswapV2PricingModule.feeOn());
        //And: feeTo on the UniswapV2 factory is the zero-address (fees are on)
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(address(0));

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2PricingModule.syncFee();

        //Then: feeOn is false
        assertTrue(!uniswapV2PricingModule.feeOn());
    }
}

/*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract AssetManagement is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_setAssetInformation_Unauthorised(address unprivilegedAddress) public {
        //Given: unprivilegedAddress is not protocol deployer
        vm.assume(unprivilegedAddress != creatorAddress);

        //When: unprivilegedAddress adds a new asset
        //Then: setAssetInformation reverts with "Ownable: caller is not the owner"
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_NonWhiteListedUnderlyingAsset() public {
        //Given: One of the underlying assets is not whitelisted (SafeMoon)
        //When: creator adds a new asset
        //Then: setAssetInformation reverts with "Ownable: caller is not the owner"
        vm.startPrank(creatorAddress);
        vm.expectRevert("UV2_SAI: NOT_WHITELISTED");
        uniswapV2PricingModule.setAssetInformation(address(pairSafemoonEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_WrongNumberOfCreditRatings() public {
        //Given: The number of credit ratings is not 0 and not the number of baseCurrencies
        uint16[] memory collateralFactors = new uint16[](1);
        collateralFactors[0] = 0;
        uint16[] memory liquidationThresholds = new uint16[](1);
        liquidationThresholds[0] = 100;

        //When: creator adds a new asset
        //Then: setAssetInformation reverts with "MR_AA: LENGTH_MISMATCH"
        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testSuccess_setAssetInformation_EmptyListCreditRatings() public {
        //Given: credit rating list is empty

        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_setAssetInformation_FullListCreditRatings() public {
        //Given: The number of credit ratings equals the number of baseCurrencies
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = 0;
        collateralFactors[1] = 0;
        collateralFactors[2] = 0;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = 100;
        liquidationThresholds[1] = 100;
        liquidationThresholds[2] = 100;

        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), collateralFactors, liquidationThresholds);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_setAssetInformation_OverwritesAsset() public {
        //Given: asset is added to pricing module
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));

        //When: creator adds asset again
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        //Then: Asset is in Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }
}

/*///////////////////////////////////////////////////////////////
                    WHITE LIST MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract WhiteListManagement is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_isWhiteListed_Positive() public {
        //Given: All contracts are deployed

        //When: pairSnxEth is added to the pricing module
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        //Then: pairSnxEth is white-listed
        assertTrue(uniswapV2PricingModule.isWhiteListed(address(pairSnxEth), 0));
    }

    function testSuccess_isWhiteListed_Negative(address randomAsset) public {
        //Given: All contracts are deployed

        //When: randomAsset is not added to the pricing module

        //Then: pairSnxEth is not white-listed
        assertTrue(!uniswapV2PricingModule.isWhiteListed(randomAsset, 0));
    }
}

/*///////////////////////////////////////////////////////////////
                        PRICING LOGIC
///////////////////////////////////////////////////////////////*/
contract PricingLogic is UniswapV2PricingModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_computeProfitMaximizingTrade(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices
        vm.assume(priceToken0 <= type(uint256).max / reserve0); //Overflow, only with unrealistic big numbers
        vm.assume(priceToken1 <= type(uint256).max / 997); //Overflow, only with unrealistic big priceToken1

        uint256 invariant = uint256(reserve0) * reserve1 * 1000;
        vm.assume(invariant / priceToken1 / 997 <= type(uint256).max / priceToken0); //leftSide overflows when arb is from token 1 to 0, only with unrealistic numbers
        vm.assume(invariant / priceToken0 / 997 <= type(uint256).max / priceToken1); //leftSide overflows when arb is from token 0 to 1, only with unrealistic numbers

        (bool token0ToToken1, uint256 amountIn) =
            uniswapV2PricingModule.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);

        uint112 reserveIn;
        uint112 reserveOut;
        uint256 priceTokenIn;
        uint256 priceTokenOut;
        if (token0ToToken1) {
            reserveIn = reserve0;
            reserveOut = reserve1;
            priceTokenIn = priceToken0;
            priceTokenOut = priceToken1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
            priceTokenIn = priceToken1;
            priceTokenOut = priceToken0;
        }

        uint256 maxProfit = profitArbitrage(priceTokenIn, priceTokenOut, amountIn, reserveIn, reserveOut);

        //Due to numerical rounding actual maximum might be deviating bit from calculated max, but must be in a range of 1%
        vm.assume(maxProfit <= type(uint256).max / 10001); //Prevent overflow on underlying overflows, maxProfit can still be a ridiculous big number
        assertGe(
            maxProfit * 10001 / 10000,
            profitArbitrage(priceTokenIn, priceTokenOut, amountIn * 999 / 1000, reserveIn, reserveOut)
        );
        assertGe(
            maxProfit * 10001 / 10000,
            profitArbitrage(priceTokenIn, priceTokenOut, amountIn * 1001 / 1000, reserveIn, reserveOut)
        );
    }

    function testRevert_computeProfitMaximizingTrade_token0ToToken1Overflows(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices

        vm.assume(priceToken0 > type(uint256).max / reserve0);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        uniswapV2PricingModule.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);
    }

    function testRevert_computeProfitMaximizingTrade_leftSideOverflows(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices
        vm.assume(priceToken0 <= type(uint256).max / reserve0); //Overflow, only with unrealistic big numbers
        vm.assume(priceToken1 <= type(uint256).max / 997); //Overflow, only with unrealistic big priceToken1

        bool token0ToToken1 = reserve0 * priceToken0 / reserve1 < priceToken1;
        uint256 invariant = uint256(reserve0) * reserve1 * 1000;
        uint256 prod;
        uint256 denominator;
        if (token0ToToken1) {
            prod = priceToken1;
            denominator = priceToken0 * 997;
        } else {
            prod = priceToken0;
            denominator = priceToken1 * 997;
        }
        vm.assume(invariant / denominator > type(uint256).max / prod);

        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(invariant, prod, not(0))
            prod0 := mul(invariant, prod)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        vm.expectRevert(abi.encodeWithSignature("PRBMath__MulDivOverflow(uint256,uint256)", prod1, denominator));
        uniswapV2PricingModule.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);
    }

    function profitArbitrage(
        uint256 priceTokenIn,
        uint256 priceTokenOut,
        uint256 amountIn,
        uint112 reserveIn,
        uint112 reserveOut
    ) internal returns (uint256 profit) {
        uint256 amountOut = uniswapV2PricingModule.getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut > 0) vm.assume(priceTokenOut <= type(uint256).max / amountOut);
        vm.assume(priceTokenIn <= type(uint256).max / amountIn);
        profit = priceTokenOut * amountOut - priceTokenIn * amountIn;
    }

    function testSuccess_computeTokenAmounts_FeeOff(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public {
        vm.assume(totalSupply > 0); // division by 0
        vm.assume(reserve0 > 0); // division by 0
        vm.assume(reserve1 > 0); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(liquidityAmount <= type(uint256).max / reserve0); // overflow, unrealistic big liquidityAmount
        vm.assume(liquidityAmount <= type(uint256).max / reserve1); // overflow, unrealistic big liquidityAmount

        uint256 token0AmountExpected = liquidityAmount * reserve0 / totalSupply;
        uint256 token1AmountExpected = liquidityAmount * reserve1 / totalSupply;

        (uint256 token0AmountActual, uint256 token1AmountActual) =
            uniswapV2PricingModule.computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, 0);

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected);
    }

    function testSuccess_computeTokenAmounts_FeeOn(
        uint112 reserve0Last,
        uint112 reserve1Last,
        uint112 reserve0,
        uint144 totalSupply, //might overflow for totalsupply bigger than 2¨^144
        uint144 liquidityAmount
    ) public {
        vm.assume(totalSupply > 10e6); // division by 0
        vm.assume(reserve0Last > 10e6); // division by 0
        vm.assume(reserve1Last > 10e6); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(reserve0 > reserve0Last); // Uniswap accrues fees

        vm.assume(uint256(reserve0) * reserve1Last / reserve0Last <= type(uint112).max); // reserve1 is max uint112 (uniswap)
        uint112 reserve1 = uint112(uint256(reserve0) * reserve1Last / reserve0Last); // pool is still balanced and fees accrued

        // Given: Fees are enabled
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(address(1));
        uniswapV2PricingModule.syncFee();

        uint256 token0Fee = (reserve0 - reserve0Last) / 6; // a sixth of all fees go to the Uniswap treasury when fees are enabled
        uint256 token1Fee = (reserve1 - reserve1Last) / 6;

        uint256 token0AmountExpected = uint256(liquidityAmount) * (reserve0 - token0Fee) / totalSupply; // substract the fees to the treasury from the reserves
        uint256 token1AmountExpected = uint256(liquidityAmount) * (reserve1 - token1Fee) / totalSupply;

        uint256 kLast = uint256(reserve0Last) * reserve1Last;
        (uint256 token0AmountActual, uint256 token1AmountActual) =
            uniswapV2PricingModule.computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);

        assertInRange(token0AmountActual, token0AmountExpected, 3); // Due numerical errors (integer divisions, and sqrt function) result will not be exactly equal
        assertInRange(token1AmountActual, token1AmountExpected, 3);
    }

    function testRevert_getTrustedReserves_Zeroreserves() public {}

    function testSuccess_getTrustedReserves_Balanced() public {}

    function testSuccess_getTrustedReserves_Unbalanced_TokenOToToken1() public {}

    function testSuccess_getTrustedReserves_Unbalanced_Token1ToToken0() public {}

    function testRevert_getTrustedTokenAmounts_UnsufficientLiquidity() public {}

    function testSuccess_getTrustedTokenAmounts() public {}

    function testRevert_getValue_Overflow(
        uint112 amountSnx,
        uint112 amountEth,
        uint8 _ethDecimals,
        uint8 _snxDecimals,
        uint8 _oracleEthToUsdDecimals,
        uint8 _oracleSnxToUsdDecimals,
        uint144 _rateEthToUsd,
        uint144 _rateSnxToUsd
    ) public {
        vm.assume(_ethDecimals <= 18);
        vm.assume(_snxDecimals <= 18);
        vm.assume(_oracleEthToUsdDecimals <= 18);
        vm.assume(_oracleSnxToUsdDecimals <= 18);
        vm.assume(_rateEthToUsd > 0);
        vm.assume(_rateSnxToUsd > 0);
        vm.assume(_rateEthToUsd <= uint256(type(int256).max));
        vm.assume(_rateSnxToUsd <= uint256(type(int256).max));

        // Redeploi tokens with variable amount of decimals
        eth =
            deployToken(oracleEthToUsd, _ethDecimals, _oracleEthToUsdDecimals, _rateEthToUsd, "ETH", oracleEthToUsdArr);
        snx =
            deployToken(oracleSnxToUsd, _snxDecimals, _oracleSnxToUsdDecimals, _rateSnxToUsd, "SNX", oracleSnxToUsdArr);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        // Mint LP
        vm.assume(uint256(amountSnx) * amountEth > pairSnxEth.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairSnxEth.mint(tokenCreatorAddress, amountSnx, amountEth);

        bool cond0 = uint256(_rateSnxToUsd) > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleSnxToUsdDecimals; // trustedPriceSnxToUsd overflows
        bool cond1 = uint256(_rateEthToUsd) > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleEthToUsdDecimals; // trustedPriceEthToUsd overflows
        vm.assume(cond0 || cond1); 

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: pairSnxEth.totalSupply(),
            baseCurrency: Constants.UsdBaseCurrency
        });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        uniswapV2PricingModule.getValue(getValueInput);
    }

    function testSuccess_getValue(
        uint112 amountSnx,
        uint8 _ethDecimals,
        uint8 _snxDecimals,
        uint8 _oracleEthToUsdDecimals,
        uint8 _oracleSnxToUsdDecimals,
        uint144 _rateEthToUsd,
        uint144 _rateSnxToUsd
    ) public {
        vm.assume(_ethDecimals <= 18);
        vm.assume(_snxDecimals <= 18);
        vm.assume(_oracleEthToUsdDecimals <= 18);
        vm.assume(_oracleSnxToUsdDecimals <= 18);
        vm.assume(_rateEthToUsd > 0);
        vm.assume(_rateSnxToUsd > 0);

        // Redeploi tokens with variable amount of decimals
        eth =
            deployToken(oracleEthToUsd, _ethDecimals, _oracleEthToUsdDecimals, _rateEthToUsd, "ETH", oracleEthToUsdArr);
        snx =
            deployToken(oracleSnxToUsd, _snxDecimals, _oracleSnxToUsdDecimals, _rateSnxToUsd, "SNX", oracleSnxToUsdArr);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyListUint16, emptyListUint16);

        // Mint a variable amount of balanced LP, for a given amountSnx
        vm.assume(
            uint256(amountSnx) * uint256(_rateSnxToUsd)
                < type(uint256).max / 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
        ); //Avoid overflow of amountEth in next line
        uint256 amountEth = uint256(amountSnx) * uint256(_rateSnxToUsd) * 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
            / (_rateEthToUsd * 10 ** (_snxDecimals + _oracleSnxToUsdDecimals));
        vm.assume(amountEth < type(uint112).max); //max reserve in Uniswap pool
        vm.assume(amountSnx * amountEth > pairSnxEth.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairSnxEth.mint(tokenCreatorAddress, amountSnx, amountEth);

        //No overflows
        vm.assume(
            uint256(_rateSnxToUsd) <= type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleSnxToUsdDecimals
        ); // trustedPriceSnxToUsd does not overflow
        uint256 trustedPriceSnxToUsd =
            Constants.WAD * uint256(_rateSnxToUsd) / 10 ** _oracleSnxToUsdDecimals * Constants.WAD / 10 ** _snxDecimals;
        vm.assume(
            uint256(_rateEthToUsd) <= type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleEthToUsdDecimals
        ); // trustedPriceEthToUsd does not overflow
        uint256 trustedPriceEthToUsd =
            Constants.WAD * uint256(_rateEthToUsd) / 10 ** _oracleEthToUsdDecimals * Constants.WAD / 10 ** _ethDecimals;
        vm.assume(trustedPriceSnxToUsd <= type(uint256).max / amountSnx); // _computeProfitMaximizingTrade does not overflow
        vm.assume(trustedPriceEthToUsd <= type(uint256).max / 997); // _computeProfitMaximizingTrade does not overflow

        uint256 valueSnx =
            Constants.WAD * _rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals * amountSnx / 10 ** _snxDecimals;
        uint256 valueEth =
            Constants.WAD * _rateEthToUsd / 10 ** _oracleEthToUsdDecimals * amountEth / 10 ** _ethDecimals;
        uint256 expectedValueInUsd = valueSnx + valueEth;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: pairSnxEth.totalSupply(),
            baseCurrency: Constants.UsdBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertInRange(actualValueInUsd, expectedValueInUsd, 4);
        assertEq(actualValueInBaseCurrency, 0);
    }

    //Helper Functions

    function assertInRange(uint256 actualValue, uint256 expectedValue, uint8 precision) internal {
        if (expectedValue == 0) {
            assertEq(actualValue, expectedValue);
        } else {
            vm.assume(expectedValue > 10 ** (2 * precision));
            assertGe(actualValue * (10 ** precision + 1) / 10 ** precision, expectedValue);
            assertLe(actualValue * (10 ** precision - 1) / 10 ** precision, expectedValue);
        }
    }

    function deployToken(
        ArcadiaOracle oracleTokenToUsd,
        uint8 tokenDecimals,
        uint8 oracleTokenToUsdDecimals,
        uint256 rate,
        string memory label,
        address[] memory oracleTokenToUsdArr
    ) internal returns (ERC20Mock token) {
        token =
            new ERC20Mock(string(abi.encodePacked(label, " Mock")), string(abi.encodePacked("m", label)), tokenDecimals);
        oracleTokenToUsd = arcadiaOracleFixture.initMockedOracle(
            oracleTokenToUsdDecimals, string(abi.encodePacked(label, " / USD")), rate
        );
        oracleTokenToUsdArr[0] = address(oracleTokenToUsd);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** oracleTokenToUsdDecimals),
                baseAssetBaseCurrency: 0,
                quoteAsset: label,
                baseAsset: "USD",
                oracleAddress: address(oracleTokenToUsd),
                quoteAssetAddress: address(token),
                baseAssetIsBaseCurrency: true
            })
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleTokenToUsdArr,
                assetUnit: uint64(10 ** tokenDecimals),
                assetAddress: address(token)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();
    }
}
