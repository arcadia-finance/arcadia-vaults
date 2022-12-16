/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import "../mockups/UniswapV2FactoryMock.sol";
import "../mockups/UniswapV2PairMock.sol";
import "../AssetRegistry/UniswapV2PricingModule.sol";

contract UniswapV2PricingModuleExtension is UniswapV2PricingModule {
    constructor(address mainRegistry_, address oracleHub_, address uniswapV2Factory_, address erc20PricingModule_)
        UniswapV2PricingModule(mainRegistry_, oracleHub_, uniswapV2Factory_, erc20PricingModule_)
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

abstract contract UniswapV2PricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    UniswapV2FactoryMock public uniswapV2Factory;
    UniswapV2PairMock public uniswapV2Pair;
    UniswapV2PairMock public pairSnxEth;
    UniswapV2PairMock public pairSafemoonEth;

    ArcadiaOracle public oracleSnxToUsd;

    UniswapV2PricingModuleExtension public uniswapV2PricingModule;

    address public haydenAdams = address(10);
    address public lpProvider = address(11);

    address[] public oracleSnxToUsdArr = new address[](1);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(haydenAdams);
        uniswapV2Factory = new UniswapV2FactoryMock();
        uniswapV2Pair = new UniswapV2PairMock();
        address pairSnxEthAddr = uniswapV2Factory.createPair(address(snx), address(eth));
        pairSnxEth = UniswapV2PairMock(pairSnxEthAddr);
        address pairSafemoonEthAddr = uniswapV2Factory.createPair(address(safemoon), address(eth));
        pairSafemoonEth = UniswapV2PairMock(pairSafemoonEthAddr);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
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

    function testRevert_addAsset_Unauthorised(address unprivilegedAddress_) public {
        //Given: unprivilegedAddress_ is not protocol deployer
        vm.assume(unprivilegedAddress_ != creatorAddress);

        //When: unprivilegedAddress_ adds a new asset
        //Then: addAsset reverts with "Ownable: caller is not the owner"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testRevert_addAsset_NonWhiteListedUnderlyingAsset() public {
        //Given: One of the underlying assets is not whitelisted (SafeMoon)
        //When: creator adds a new asset
        //Then: addAsset reverts with "Ownable: caller is not the owner"
        vm.startPrank(creatorAddress);
        vm.expectRevert("PMUV2_AA: NOT_WHITELISTED");
        uniswapV2PricingModule.addAsset(address(pairSafemoonEth), emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListCreditRatings() public {
        //Given: credit rating list is empty

        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_addAsset_OwnerAddsAssetWithNonFullListRiskVariables() public {
        //Given: The number of credit ratings is not 0 and not the number of baseCurrencies
        PricingModule.RiskVarInput[] memory collateralFactors_ = new PricingModule.RiskVarInput[](1);
        collateralFactors_[0] = PricingModule.RiskVarInput({baseCurrency:0, value:collFactor});
        PricingModule.RiskVarInput[] memory liquidationThresholds_ = new PricingModule.RiskVarInput[](1);
        liquidationThresholds_[0] = PricingModule.RiskVarInput({baseCurrency:0, value:liqTresh});
        //When: creator adds a new asset
        //Then: addAsset reverts with "APM_SRV: LENGTH_MISMATCH"
        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), collateralFactors_, liquidationThresholds_);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testSuccess_addAsset_FullListCreditRatings() public {
        //Given: The number of credit ratings equals the number of baseCurrencies
        //When: creator adds a new asset
        vm.prank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), collateralFactors, liquidationThresholds);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));
    }

    function testRevert_addAsset_OwnerOverwritesExistingAsset() public {
        //Given: asset is added to pricing module
        vm.prank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairSnxEth)));

        //When: creator adds asset again
        vm.prank(creatorAddress);
        vm.expectRevert("PMUV2_AA: already added");
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);
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
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);

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
    using stdStorage for StdStorage;

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

    function testRevert_getTrustedReserves_Zeroreserves(uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        public
    {
        vm.expectRevert("UV2_GTR: ZERO_PAIR_RESERVES");
        uniswapV2PricingModule.getTrustedReserves(address(pairSnxEth), trustedPriceToken0, trustedPriceToken1);
    }

    function testSuccess_getTrustedReserves(
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

        pairSnxEth.setReserves(reserve0, reserve1);

        (bool token0ToToken1, uint256 amountIn) =
            uniswapV2PricingModule.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);

        uint256 amountOut;
        uint256 expectedTrustedReserve0;
        uint256 expectedTrustedReserve1;
        if (token0ToToken1) {
            amountOut = uniswapV2PricingModule.getAmountOut(amountIn, reserve0, reserve1);
            expectedTrustedReserve0 = reserve0 + amountIn;
            expectedTrustedReserve1 = reserve1 - amountOut;
        } else {
            amountOut = uniswapV2PricingModule.getAmountOut(amountIn, reserve1, reserve0);
            expectedTrustedReserve0 = reserve0 - amountOut;
            expectedTrustedReserve1 = reserve1 + amountIn;
        }

        (uint256 actualTrustedReserve0, uint256 actualTrustedReserve1) =
            uniswapV2PricingModule.getTrustedReserves(address(pairSnxEth), priceToken0, priceToken1);
        assertEq(actualTrustedReserve0, expectedTrustedReserve0);
        assertEq(actualTrustedReserve1, expectedTrustedReserve1);
    }

    function testRevert_getTrustedTokenAmounts_UnsufficientLiquidity(uint256 priceToken0, uint256 priceToken1) public {
        vm.expectRevert("UV2_GTTA: LIQUIDITY_AMOUNT");
        uniswapV2PricingModule.getTrustedTokenAmounts(address(pairSnxEth), priceToken0, priceToken1, 0);
    }

    function testSuccess_getTrustedTokenAmounts(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public {
        // Only test for balanced pool, other tests guarantee that _getTrustedReserves brings unbalanced pool into balance
        vm.assume(liquidityAmount > 0); // division by 0
        vm.assume(reserve0 > 0); // division by 0
        vm.assume(reserve1 > 0); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(liquidityAmount <= type(uint256).max / reserve0); // overflow, unrealistic big liquidityAmount
        vm.assume(liquidityAmount <= type(uint256).max / reserve1); // overflow, unrealistic big liquidityAmount

        // Given: The reserves in the pool are reserve0 and reserve1
        pairSnxEth.setReserves(reserve0, reserve1);
        // And: The liquidity in the pool is totalSupply
        stdstore.target(address(pairSnxEth)).sig(pairSnxEth.totalSupply.selector).checked_write(totalSupply);
        // And: The pool is balanced
        uint256 trustedPriceToken0 = reserve1;
        uint256 trustedPriceToken1 = reserve0;

        uint256 token0AmountExpected = liquidityAmount * reserve0 / totalSupply;
        uint256 token1AmountExpected = liquidityAmount * reserve1 / totalSupply;

        (uint256 token0AmountActual, uint256 token1AmountActual) = uniswapV2PricingModule.getTrustedTokenAmounts(
            address(pairSnxEth), trustedPriceToken0, trustedPriceToken1, liquidityAmount
        );

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected);
    }

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

        // Redeploy tokens with variable amount of decimals
        eth =
            deployToken(oracleEthToUsd, _ethDecimals, _oracleEthToUsdDecimals, _rateEthToUsd, "ETH", oracleEthToUsdArr);
        snx =
            deployToken(oracleSnxToUsd, _snxDecimals, _oracleSnxToUsdDecimals, _rateSnxToUsd, "SNX", oracleSnxToUsdArr);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));
        vm.prank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);

        // Mint LP
        vm.assume(uint256(amountSnx) * amountEth > pairSnxEth.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairSnxEth.mint(tokenCreatorAddress, amountSnx, amountEth);

        bool cond0 =
            uint256(_rateSnxToUsd) > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleSnxToUsdDecimals; // trustedPriceSnxToUsd overflows
        bool cond1 =
            uint256(_rateEthToUsd) > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleEthToUsdDecimals; // trustedPriceEthToUsd overflows
        vm.assume(cond0 || cond1);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(pairSnxEth),
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

        // Redeploy tokens with variable amount of decimals
        eth =
            deployToken(oracleEthToUsd, _ethDecimals, _oracleEthToUsdDecimals, _rateEthToUsd, "ETH", oracleEthToUsdArr);
        snx =
            deployToken(oracleSnxToUsd, _snxDecimals, _oracleSnxToUsdDecimals, _rateSnxToUsd, "SNX", oracleSnxToUsdArr);
        pairSnxEth = UniswapV2PairMock(uniswapV2Factory.createPair(address(snx), address(eth)));
        vm.prank(creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairSnxEth), emptyRiskVarInput, emptyRiskVarInput);

        // Mint a variable amount of balanced LP, for a given amountSnx
        vm.assume(
            uint256(amountSnx) * uint256(_rateSnxToUsd)
                < type(uint256).max / 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
        ); //Avoid overflow of amountEth in next line
        uint256 amountEth = uint256(amountSnx) * uint256(_rateSnxToUsd) * 10 ** (_ethDecimals + _oracleEthToUsdDecimals)
            / _rateEthToUsd / 10 ** (_snxDecimals + _oracleSnxToUsdDecimals);
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
            asset: address(pairSnxEth),
            assetId: 0,
            assetAmount: pairSnxEth.totalSupply(),
            baseCurrency: Constants.UsdBaseCurrency
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = uniswapV2PricingModule.getValue(getValueInput);

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
                oracle: address(oracleTokenToUsd),
                quoteAssetAddress: address(token),
                baseAssetIsBaseCurrency: true
            })
        );
        standardERC20PricingModule.addAsset(address(token), oracleTokenToUsdArr, emptyRiskVarInput, emptyRiskVarInput);
        vm.stopPrank();
    }
}
