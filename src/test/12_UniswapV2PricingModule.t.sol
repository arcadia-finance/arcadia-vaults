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

    StandardERC20PricingModule public standardERC20PricingModule;
    UniswapV2PricingModule public uniswapV2PricingModule;

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

    uint256[] emptyList = new uint256[](0);

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
            emptyList
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyList
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
            emptyList
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );

        uniswapV2PricingModule = new UniswapV2PricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(uniswapV2Factory)
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

    function testOwnerAddsAssetWithWrongNumberOfCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), assetCreditRatings);
        vm.stopPrank();
    }

    function testOwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testOwnerAddsAssetWithFullListCreditRatings() public {
        vm.startPrank(creatorAddress);
        uint256[] memory assetCreditRatings = new uint256[](3);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        assetCreditRatings[2] = 0;
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), assetCreditRatings);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testOwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    //Test isWhiteListed
    function testIsWhitelistedPositive() public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.isWhiteListed(address(pairSnxEth), 0));
    }

    function testIsWhitelistedNegative(address randomAsset) public {
        assertTrue(!uniswapV2PricingModule.isWhiteListed(randomAsset, 0));
    }

    //Test getValue
    function testReturnValueInUsdFromBalancedPair(uint112 amountSnx) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

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

    function testReturnValueInEthFromBalancedPair(uint112 amountSnx) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

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

    function testReturnValueInEthFromUnbalancedPair(uint112 amountSnx, uint112 amountEthSwapped) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

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

    function testReturnValueInEthFromVeryUnbalancedPair(uint112 amountSnx, uint112 amountEthSwapped) public {
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

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
        uint128 _rateSnxToUsd
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
        ArcadiaOracle oracleSnxToUsd = arcadiaOracleFixture.initMockedOracle(0, "SNX / USD", _rateSnxToUsd);
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
        address[] memory oracleSnxToUsdArr = new address[](1);
        oracleSnxToUsdArr[0] = address(oracleSnxToUsd);

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** _ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToUsdArr,
                assetUnit: uint64(10 ** _snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

        uint256 amount = pairSnxEth.mint(lpProvider, amountSnx, amountEth);

        vm.assume(Constants.WAD * _rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals < type(uint256).max / amountSnx);
        vm.assume(Constants.WAD * _rateEthToUsd / 10 ** _oracleEthToUsdDecimals < type(uint256).max / amountEth);
        uint256 valueSnx =
            Constants.WAD * _rateSnxToUsd / 10 ** _oracleSnxToUsdDecimals * amountSnx / 10 ** _snxDecimals;
        uint256 valueEth =
            Constants.WAD * _rateEthToUsd / 10 ** _oracleEthToUsdDecimals * amountEth / 10 ** _ethDecimals;
        uint256 expectedValueInBaseCurrency = valueSnx + valueEth;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(pairSnxEth),
            assetId: 0,
            assetAmount: amount,
            baseCurrency: Constants.UsdBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = uniswapV2PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, 0);
        assertInRange(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testReturnValueFromBalancedPairOverflow(uint112 amountSnx, uint64 _rateEthToUsd, uint128 _rateSnxToUsd)
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
        ArcadiaOracle oracleSnxToUsd = arcadiaOracleFixture.initMockedOracle(0, "SNX / USD", _rateSnxToUsd);
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
        address[] memory oracleSnxToUsdArr = new address[](1);
        oracleSnxToUsdArr[0] = address(oracleSnxToUsd);

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** _ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToUsdArr,
                assetUnit: uint64(10 ** _snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

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
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_NonWhiteListedUnderlyingAsset() public {
        //Given: One of the underlying assets is not whitelisted (SafeMoon)
        //When: creator adds a new asset
        //Then: setAssetInformation reverts with "Ownable: caller is not the owner"
        vm.startPrank(creatorAddress);
        vm.expectRevert("UV2_SAI: NOT_WHITELISTED");
        uniswapV2PricingModule.setAssetInformation(address(pairSafemoonEth), emptyList);
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_WrongNumberOfCreditRatings() public {
        //Given: The number of credit ratings is not 0 and not the number of baseCurrencies
        uint256[] memory assetCreditRatings = new uint256[](1);
        assetCreditRatings[0] = 0;

        //When: creator adds a new asset
        //Then: setAssetInformation reverts with "MR_AA: LENGTH_MISMATCH"
        vm.startPrank(creatorAddress);
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), assetCreditRatings);
        vm.stopPrank();
    }

    function testSuccess_setAssetInformation_EmptyListCreditRatings() public {
        //Given: credit rating list is empty

        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_setAssetInformation_FullListCreditRatings() public {
        //Given: The number of credit ratings equals the number of baseCurrencies
        uint256[] memory assetCreditRatings = new uint256[](3);
        assetCreditRatings[0] = 0;
        assetCreditRatings[1] = 0;
        assetCreditRatings[2] = 0;

        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), assetCreditRatings);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_setAssetInformation_OverwritesAsset() public {
        //Given: asset is added to pricing module
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));

        //When: creator adds asset again
        vm.prank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairSnxEth), emptyList);

        //Then: Asset is in Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }
}
