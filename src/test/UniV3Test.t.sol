/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import { DeployedContracts, OracleHub, Vault } from "./fixtures/DeployedContracts.f.sol";
import { ERC20Fixture } from "./fixtures/ERC20Fixture.f.sol";
import { ArcadiaOracleFixture, ArcadiaOracle } from "./fixtures/ArcadiaOracleFixture.f.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../lib/solmate/src/tokens/ERC721.sol";
import {
    UniswapV3PricingModule,
    PricingModule,
    IPricingModule,
    TickMath,
    LiquidityAmounts,
    FixedPointMathLib
} from "../PricingModules/UniswapV3/UniswapV3PricingModule.sol";
import { INonfungiblePositionManagerExtension } from "./interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from "./interfaces/IUniswapV3PoolExtension.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { LiquidityAmountsExtension } from "./libraries/LiquidityAmountsExtension.sol";
import { TickMathsExtension } from "./libraries/TickMathsExtension.sol";

contract UniswapV3PricingModuleExtension is UniswapV3PricingModule {
    constructor(address mainRegistry_, address oracleHub_, address riskManager_, address erc20PricingModule_)
        UniswapV3PricingModule(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_)
    { }

    function getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 usdPriceToken0,
        uint256 usdPriceToken1
    ) public pure returns (uint256 amount0, uint256 amount1) {
        return _getPrincipalAmounts(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        return _getSqrtPriceX96(priceToken0, priceToken1);
    }

    function getTickTwap(IUniswapV3PoolExtension pool) external view returns (int24 tick) {
        return _getTwat(pool);
    }

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
    }

    function getFeeAmounts(address asset, uint256 id) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getFeeAmounts(asset, id);
    }
}

abstract contract UniV3Test is DeployedContracts, Test {
    string RPC_URL = vm.envString("RPC_URL");
    uint256 fork;

    address public liquidityProvider = address(1);
    address public swapper = address(2);
    address public user = address(3);

    UniswapV3PricingModuleExtension uniV3PricingModule;
    INonfungiblePositionManagerExtension public uniV3 =
        INonfungiblePositionManagerExtension(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory public uniV3factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    ERC20Fixture erc20Fixture;
    ArcadiaOracleFixture oracleFixture;

    event RiskManagerUpdated(address riskManager);
    event MaxExposureSet(address indexed asset, uint128 maxExposure);

    //this is a before
    constructor() {
        fork = vm.createFork(RPC_URL);

        erc20Fixture = new ERC20Fixture();
        oracleFixture = new ArcadiaOracleFixture(deployer);
        vm.makePersistent(address(erc20Fixture));
        vm.makePersistent(address(oracleFixture));
    }

    //this is a before each
    function setUp() public virtual { }

    /*///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/
    function isBelowMaxLiquidityPerTick(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        IUniswapV3PoolExtension pool_
    ) public view returns (bool) {
        (uint160 sqrtPrice,,,,,,) = pool_.slot0();

        uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), amount0, amount1
        );

        return liquidity <= pool_.maxLiquidityPerTick();
    }

    function isWithinAllowedRange(int24 tick) public pure returns (bool) {
        int24 MIN_TICK = -887_272;
        int24 MAX_TICK = -MIN_TICK;
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
    }

    function createPool(ERC20 token0, ERC20 token1, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        address poolAddress =
            uniV3.createAndInitializePoolIfNecessary(address(token0), address(token1), 100, sqrtPriceX96); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        (uint160 sqrtPrice,,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        tokenId = addLiquidity(pool, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
        if (!revertsOnZeroLiquidity) {
            (uint160 sqrtPrice,,,,,,) = pool.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();

        deal(token0, liquidityProvider_, amount0);
        deal(token1, liquidityProvider_, amount1);
        vm.startPrank(liquidityProvider_);
        ERC20(token0).approve(address(uniV3), type(uint256).max);
        ERC20(token1).approve(address(uniV3), type(uint256).max);
        (tokenId,,,) = uniV3.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function addUnderlyingTokenToArcadia(address token, int256 price) internal {
        ArcadiaOracle oracle = oracleFixture.initMockedOracle(0, "Token / USD");
        address[] memory oracleArr = new address[](1);
        oracleArr[0] = address(oracle);
        PricingModule.RiskVarInput[] memory riskVars = new PricingModule.RiskVarInput[](1);
        riskVars[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: 80,
            liquidationFactor: 90
        });

        vm.startPrank(deployer);
        oracle.transmit(price);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 1,
                quoteAssetBaseCurrency: 0,
                baseAsset: "Token",
                quoteAsset: "USD",
                oracle: address(oracle),
                baseAssetAddress: token,
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );
        standardERC20PricingModule.addAsset(token, oracleArr, riskVars, type(uint128).max);
        vm.stopPrank();
    }

    function assertInRange(uint256 actualValue, uint256 expectedValue, uint8 precision) internal {
        if (expectedValue == 0) {
            assertEq(actualValue, expectedValue);
        } else {
            vm.assume(expectedValue > 10 ** (2 * precision));
            assertGe(actualValue * (10 ** precision + 1) / 10 ** precision, expectedValue);
            assertLe(actualValue * (10 ** precision - 1) / 10 ** precision, expectedValue);
        }
    }
}

/* ///////////////////////////////////////////////////////////////
                        DEPLOYMENT
/////////////////////////////////////////////////////////////// */
contract DeploymentTest is UniV3Test {
    function setUp() public override { }

    function testSuccess_deployment(
        address mainRegistry_,
        address oracleHub_,
        address riskManager_,
        address erc20PricingModule_
    ) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        uniV3PricingModule =
            new UniswapV3PricingModuleExtension(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_);
        vm.stopPrank();

        assertEq(uniV3PricingModule.assetType(), 1);
    }
}

/*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract AssetManagementTest is UniV3Test {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        vm.selectFork(fork);

        vm.startPrank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();
    }

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != deployer);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3PricingModule.addAsset(address(uniV3));
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));
        vm.expectRevert("PMUV3_AA: already added");
        uniV3PricingModule.addAsset(address(uniV3));
        vm.stopPrank();
    }

    function testRevert_addAsset_MainRegistryReverts() public {
        vm.prank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));

        vm.startPrank(deployer);
        vm.expectRevert("MR: Only PriceMod.");
        uniV3PricingModule.addAsset(address(uniV3));
        vm.stopPrank();
    }

    function testSuccess_addAsset() public {
        vm.prank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));

        address factory_ = uniV3.factory();
        assertTrue(uniV3PricingModule.inPricingModule(address(uniV3)));
        assertEq(uniV3PricingModule.assetsInPricingModule(0), address(uniV3));
        assertEq(uniV3PricingModule.assetToV3Factory(address(uniV3)), factory_);
    }
}

/*///////////////////////////////////////////////////////////////
                    ALLOW LIST MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract AllowListManagementTest is UniV3Test {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        vm.selectFork(fork);

        vm.startPrank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();

        vm.prank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));
    }

    function testSuccess_isAllowListed_NegativeUnknownAsset(address asset, uint256 assetId) public {
        vm.assume(asset != address(uniV3));

        assertFalse(uniV3PricingModule.isAllowListed(asset, assetId));
    }

    function testSuccess_isAllowListed_NegativeNoExposure(uint256 assetId) public {
        bound(assetId, 1, uniV3.totalSupply());

        assertFalse(uniV3PricingModule.isAllowListed(address(uniV3), assetId));
    }

    function testSuccess_isAllowListed_NegativeUnknownId(uint256 assetId) public {
        bound(assetId, 2 * uniV3.totalSupply(), type(uint256).max);

        assertFalse(uniV3PricingModule.isAllowListed(address(uniV3), assetId));
    }

    function testSuccess_isAllowListed_Positive(address lp, uint128 maxExposureA, uint128 maxExposureB) public {
        vm.assume(lp != address(0));
        vm.assume(maxExposureA > 0);
        vm.assume(maxExposureB > 0);

        // Create a LP-position of two underlying assets: tokenA and tokenB.
        ERC20 tokenA = erc20Fixture.createToken();
        ERC20 tokenB = erc20Fixture.createToken();
        uniV3.createAndInitializePoolIfNecessary(address(tokenA), address(tokenB), 100, 1 << 96);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(uniV3), type(uint256).max);
        tokenB.approve(address(uniV3), type(uint256).max);
        (uint256 tokenId,,,) = uniV3.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                fee: 100,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        // Set a maxExposure for tokenA and tokenB greater than 0.
        vm.startPrank(deployer);
        uniV3PricingModule.setExposure(address(tokenA), 1, maxExposureA);
        uniV3PricingModule.setExposure(address(tokenB), 1, maxExposureB);
        vm.stopPrank();

        // Test that Uni V3 LP token with allowed exposure to the underlying assets is allowlisted.
        assertTrue(uniV3PricingModule.isAllowListed(address(uniV3), tokenId));
    }
}

/*///////////////////////////////////////////////////////////////
                RISK VARIABLES MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract RiskVariablesManagementTest is UniV3Test {
    using stdStorage for StdStorage;

    ERC20 token0;
    ERC20 token1;
    IUniswapV3PoolExtension pool;

    // Before Each.
    function setUp() public override {
        super.setUp();
        vm.selectFork(fork);

        vm.startPrank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();

        vm.prank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));

        token0 = erc20Fixture.createToken();
        token1 = erc20Fixture.createToken();
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    function testRevert_setExposureOfAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint128 maxExposure
    ) public {
        vm.assume(unprivilegedAddress_ != deployer);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        uniV3PricingModule.setExposureOfAsset(asset, maxExposure);
        vm.stopPrank();
    }

    function testRevert_setExposureOfAsset_UnknownAsset(uint128 maxExposure) public {
        ERC20 token = erc20Fixture.createToken();

        vm.startPrank(deployer);
        vm.expectRevert("PMUV3_SEOA: Unknown asset");
        uniV3PricingModule.setExposureOfAsset(address(token), maxExposure);
        vm.stopPrank();
    }

    function testSuccess_setExposureOfAsset(uint128 maxExposure) public {
        ERC20 token = erc20Fixture.createToken();
        addUnderlyingTokenToArcadia(address(token), 1);

        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(address(token), maxExposure);
        uniV3PricingModule.setExposureOfAsset(address(token), maxExposure);
        vm.stopPrank();

        (uint128 actualMaxExposure,) = uniV3PricingModule.exposure(address(token));
        assertEq(actualMaxExposure, maxExposure);
    }

    function testSuccess_getTwat(
        uint256 timePassed,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Initial,
        uint128 amountOut0,
        uint128 amountOut1
    ) public {
        // Limit timePassed between the two swaps to 300s (the TWAT duration).
        timePassed = bound(timePassed, 0, 300);

        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Check that amounts are within allowed ranges.
        vm.assume(amountOut0 > 0);
        vm.assume(amountOut1 > 10); // Avoid error "SPL" when amountOut1is very small and amountOut0~amount0Initial.
        vm.assume(uint256(amountOut0) + amountOut1 < amount0Initial);

        // Create a pool with the minimum initial price (4_295_128_739) and cardinality 300.
        pool = createPool(token0, token1, 4_295_128_739, 300);
        vm.assume(isBelowMaxLiquidityPerTick(tickLower, tickUpper, amount0Initial, 0, pool));

        // Provide liquidity only in token0.
        addLiquidity(pool, amount0Initial, 0, liquidityProvider, tickLower, tickUpper, false);

        // Do a first swap.
        deal(address(token1), swapper, type(uint256).max);
        vm.startPrank(swapper);
        token1.approve(address(router), type(uint256).max);
        router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOut0,
                amountInMaximum: type(uint160).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );
        vm.stopPrank();

        // Cache the current tick after the first swap.
        (, int24 tick0,,,,,) = pool.slot0();

        // Do second swap after timePassed seconds.
        uint256 timestamp = block.timestamp;
        vm.warp(timestamp + timePassed);
        vm.startPrank(swapper);
        token1.approve(address(router), type(uint256).max);
        router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOut1,
                amountInMaximum: type(uint160).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );
        vm.stopPrank();

        // Cache the current tick after the second swap.
        (, int24 tick1,,,,,) = pool.slot0();

        // Calculate the TWAT.
        vm.warp(timestamp + 300);
        int256 expectedTickTwap =
            (int256(tick0) * int256(timePassed) + int256(tick1) * int256((300 - timePassed))) / 300;

        // Compare with the actual TWAT.
        int256 actualTickTwap = uniV3PricingModule.getTickTwap(pool);
        assertEq(actualTickTwap, expectedTickTwap);
    }

    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress, address asset, uint256 id) public {
        vm.assume(unprivilegedAddress != address(mainRegistry));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        uniV3PricingModule.processDeposit(address(0), asset, id, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ZeroLiquidity() public {
        // Create Uniswap V3 pool initiated at tick 0 with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, 1000, liquidityProvider, -60, 60, true);

        // Decrease liquidity so that position has 0 liquidity.
        // Fetch liquidity from position instead of using input liquidity
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        vm.prank(liquidityProvider);
        uniV3.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity_,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint160).max
            })
        );

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PMUV3_PD: 0 liquidity");
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_BelowAcceptedRange(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent
    ) public {
        // Condition on which the call should revert: tick_lower is more than 16_095 ticks below tickCurrent.
        vm.assume(tickCurrent > int256(tickLower) + 16_095);

        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);
        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PMUV3_PD: Tlow not in limits");
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_AboveAcceptedRange(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent
    ) public {
        // tick_lower is less than 16_095 ticks below tickCurrent.
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        // Condition on which the call should revert: tickUpper is more than 16_095 ticks above tickCurrent.
        vm.assume(tickCurrent < int256(tickUpper) - 16_095);

        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);
        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PMUV3_PD: Tup not in limits");
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ExposureToken0ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint128 initialExposure0,
        uint128 maxExposure0
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(tickCurrent >= int256(tickUpper) - 16_095);
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Condition on which the call should revert: exposure to token0 becomes bigger as maxExposure0.
        vm.assume(amount0 + initialExposure0 > maxExposure0);
        // Set maxExposures
        vm.startPrank(deployer);
        uniV3PricingModule.setExposure(address(token0), initialExposure0, maxExposure0);
        uniV3PricingModule.setExposure(address(token1), 0, type(uint128).max);
        vm.stopPrank();

        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PMUV3_PD: Exposure0 not in limits");
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ExposureToken1ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint128 initialExposure1,
        uint128 maxExposure1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(tickCurrent >= int256(tickUpper) - 16_095);
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Condition on which the call should revert: exposure to token1 becomes bigger as maxExposure1.
        vm.assume(amount1 + initialExposure1 > maxExposure1);
        // Set maxExposures
        vm.startPrank(deployer);
        uniV3PricingModule.setExposure(address(token0), 0, type(uint128).max);
        uniV3PricingModule.setExposure(address(token1), initialExposure1, maxExposure1);
        vm.stopPrank();

        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("PMUV3_PD: Exposure1 not in limits");
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);
        vm.stopPrank();
    }

    function testSuccess_processDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint128 initialExposure0,
        uint128 initialExposure1,
        uint128 maxExposure0,
        uint128 maxExposure1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(tickCurrent >= int256(tickUpper) - 16_095);
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Check that exposure to tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 <= maxExposure0);
        vm.assume(amount1 + initialExposure1 <= maxExposure1);
        // Set maxExposures
        vm.startPrank(deployer);
        uniV3PricingModule.setExposure(address(token0), initialExposure0, maxExposure0);
        uniV3PricingModule.setExposure(address(token1), initialExposure1, maxExposure1);
        vm.stopPrank();

        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        vm.prank(address(mainRegistry));
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);

        (, uint128 exposure0) = uniV3PricingModule.exposure(address(token0));
        (, uint128 exposure1) = uniV3PricingModule.exposure(address(token1));
        assertEq(exposure0, amount0 + initialExposure0);
        assertEq(exposure1, amount1 + initialExposure1);
    }

    function testRevert_processWithdrawal_NonMainRegistry(address unprivilegedAddress, address asset, uint256 id)
        public
    {
        vm.assume(unprivilegedAddress != address(mainRegistry));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        uniV3PricingModule.processWithdrawal(address(0), asset, id, 0);
        vm.stopPrank();
    }

    function testSuccess_processWithdrawal(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint128 initialExposure0,
        uint128 initialExposure1,
        uint128 maxExposure0,
        uint128 maxExposure1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(tickCurrent >= int256(tickUpper) - 16_095);
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate expose to underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Avoid overflow.
        vm.assume(amount0 <= type(uint128).max - initialExposure0);
        vm.assume(amount1 <= type(uint128).max - initialExposure1);
        // Check that there is sufficient free exposure.
        vm.assume(amount0 + initialExposure0 <= maxExposure0);
        vm.assume(amount1 + initialExposure1 <= maxExposure1);
        // Set maxExposures
        vm.startPrank(deployer);
        uniV3PricingModule.setExposure(address(token0), initialExposure0, maxExposure0);
        uniV3PricingModule.setExposure(address(token1), initialExposure1, maxExposure1);
        vm.stopPrank();

        // Warp 300 seconds to ensure that TWAT of 300s can be calculated.
        vm.warp(block.timestamp + 300);

        // Deposit assets (necessary to update the position in the Pricing Module).
        vm.prank(address(mainRegistry));
        uniV3PricingModule.processDeposit(address(0), address(uniV3), tokenId, 0);

        vm.prank(address(mainRegistry));
        uniV3PricingModule.processWithdrawal(address(0), address(uniV3), tokenId, 0);

        (, uint128 exposure0) = uniV3PricingModule.exposure(address(token0));
        (, uint128 exposure1) = uniV3PricingModule.exposure(address(token1));
        assertEq(exposure0, initialExposure0);
        assertEq(exposure1, initialExposure1);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/
    function testSuccess_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 1e18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint256 priceXd18 = priceToken0 * 1e18 / priceToken1;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;
        uint256 actualSqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testSuccess_getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 1e18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(priceToken0, priceToken1);
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        (uint256 actualAmount0, uint256 actualAmount1) =
            uniV3PricingModule.getPrincipalAmounts(tickLower, tickUpper, liquidity, priceToken0, priceToken1);
        assertEq(actualAmount0, expectedAmount0);
        assertEq(actualAmount1, expectedAmount1);
    }

    function testSuccess_getValue_valueInUsd(
        uint256 decimals0,
        uint256 decimals1,
        uint80 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint64 priceToken0,
        uint64 priceToken1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);
        token0 = erc20Fixture.createToken(deployer, uint8(decimals0));
        token1 = erc20Fixture.createToken(deployer, uint8(decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (decimals0, decimals1) = (decimals1, decimals0);
            (priceToken0, priceToken1) = (priceToken1, priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);
        // Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            priceToken0 * 10 ** (18 - decimals0), priceToken1 * 10 ** (18 - decimals1)
        );
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max);
        vm.assume(amount1 < type(uint104).max);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)));

        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // Calculate the expected value
        uint256 valueToken0 = 1e18 * uint256(priceToken0) * amount0 / 10 ** decimals0;
        uint256 valueToken1 = 1e18 * uint256(priceToken1) * amount1 / 10 ** decimals1;

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({ asset: address(uniV3), assetId: tokenId, assetAmount: 1, baseCurrency: 0 })
        );

        assertEq(actualValueInUsd, valueToken0 + valueToken1);
        assertEq(actualValueInBaseCurrency, 0);
    }

    function testSuccess_getValue_valueWithTokensOwed(
        uint256 decimals0,
        uint256 decimals1,
        uint80 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint64 priceToken0,
        uint64 priceToken1,
        uint256 amountOut
    ) public {
        vm.prank(deployer);
        uniV3PricingModule.setFeeFlag(UniswapV3PricingModule.FeeFlag.TokensOwed);

        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);
        token0 = erc20Fixture.createToken(deployer, uint8(decimals0));
        token1 = erc20Fixture.createToken(deployer, uint8(decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (decimals0, decimals1) = (decimals1, decimals0);
            (priceToken0, priceToken1) = (priceToken1, priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);
        //Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            priceToken0 * 10 ** (18 - decimals0), priceToken1 * 10 ** (18 - decimals1)
        );
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max && amount0 > 0);
        vm.assume(amount1 < type(uint104).max && amount1 > 0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)));

        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // amountOut cannot exceed available liquidity.
        amountOut = bound(amountOut, 1, amount0);

        // Do the swap
        deal(address(token1), swapper, type(uint256).max);
        vm.startPrank(swapper);
        token1.approve(address(router), type(uint256).max);
        uint256 amountIn = router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOut,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );
        vm.stopPrank();

        // When amountIn is smaller as fee, calculations get tricky, but overall value will be neglectible.
        vm.assume(amountIn > 10_000);

        // Calculate the expected fee in token1 (fees are only in tokenIn).
        uint256 expectedFee0 = 0;
        uint256 expectedFee1 = amountIn / 10_000;

        // We want to test tokensOwed in this test -> we first have to claim the pending fees.
        // To do this we decrease the position with minimal amount.
        vm.prank(liquidityProvider);
        (uint256 principal0, uint256 principal1) = uniV3.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: 1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint128).max
            })
        );

        (uint256 tokensOwed0, uint256 tokensOwed1) = uniV3PricingModule.getFeeAmounts(address(uniV3), tokenId);
        // Decreasing liquidity positions will also increase tokensOwed
        // To know the actual fees we have to substract the tokensOwed due to a decrease of principal LP from the total tokensOwed.
        uint256 actualFee0 = tokensOwed0 - principal0;
        uint256 actualFee1 = tokensOwed1 - principal1;

        assertEq(actualFee0, expectedFee0);
        assertInRange(actualFee1, expectedFee1, 3);
    }

    function testSuccess_getValue_valueWithFeeGrowth(
        uint256 decimals0,
        uint256 decimals1,
        uint80 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint64 priceToken0,
        uint64 priceToken1,
        uint256 amountOutA,
        uint256 amountOutB
    ) public {
        vm.prank(deployer);
        uniV3PricingModule.setFeeFlag(UniswapV3PricingModule.FeeFlag.All);

        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);
        token0 = erc20Fixture.createToken(deployer, uint8(decimals0));
        token1 = erc20Fixture.createToken(deployer, uint8(decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (decimals0, decimals1) = (decimals1, decimals0);
            (priceToken0, priceToken1) = (priceToken1, priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);
        //Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            priceToken0 * 10 ** (18 - decimals0), priceToken1 * 10 ** (18 - decimals1)
        );
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max && amount0 > 0);
        vm.assume(amount1 < type(uint104).max && amount1 > 0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)));

        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // amountOutA cannot exceed available liquidity.
        // Term (amount0 - 1) since amountOutB of second swap must be bigger as zero.
        amountOutA = bound(amountOutA, 1, amount0 - 1);

        // Do the first swap
        deal(address(token1), swapper, type(uint256).max);
        vm.startPrank(swapper);
        token1.approve(address(router), type(uint256).max);
        uint256 amountIn = router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOutA,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );
        vm.stopPrank();

        // When amountIn is smaller as fee, calculations get tricky, but overall value will be neglectible.
        vm.assume(amountIn > 10_000);

        // Calculate the expected fee in token1 (fees are only in tokenIn).
        uint256 expectedFee0 = 0;
        uint256 expectedFee1 = amountIn / 10_000;

        // We want part of the fees in tokensOwed in this test -> we have to claim the pending fees.
        // To do this we decrease the position with minimal amount.
        vm.prank(liquidityProvider);
        (uint256 principal0, uint256 principal1) = uniV3.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: 1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint128).max
            })
        );

        // We do another swap from token1 to token0 -> start price cannot be the sqrtPriceLimitX96.
        (uint160 sqrtPrice_,,,,,,) = pool.slot0();
        vm.assume(sqrtPrice_ < 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341);
        // amountOutB cannot exceed remaining liquidity.
        amountOutB = bound(amountOutB, 1, amount0 - amountOutA);

        // Do the second swap
        vm.prank(swapper);
        amountIn = router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOutB,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );

        // When amountIn is smaller as fee, calculations get tricky, but overall value will be neglectible.
        vm.assume(amountIn > 10_000);

        // Update the expected fee in token1 (fees are only in tokenIn).
        expectedFee1 += amountIn / 10_000;

        (uint256 actualFee0, uint256 actualFee1) = uniV3PricingModule.getFeeAmounts(address(uniV3), tokenId);
        // Decreasing liquidity positions will also increase tokensOwed
        // To know the actual fees we have to substract the tokensOwed due to a decrease of principal LP from the total tokensOwed.
        actualFee0 -= principal0;
        actualFee1 -= principal1;

        assertEq(actualFee0, expectedFee0);
        assertInRange(actualFee1, expectedFee1, 3);
    }

    function testSuccess_getValue_valueFeesInvariant(
        uint256 decimals0,
        uint256 decimals1,
        uint80 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint64 priceToken0,
        uint64 priceToken1,
        uint256 amountOutA,
        uint256 amountOutB
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);
        token0 = erc20Fixture.createToken(deployer, uint8(decimals0));
        token1 = erc20Fixture.createToken(deployer, uint8(decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (decimals0, decimals1) = (decimals1, decimals0);
            (priceToken0, priceToken1) = (priceToken1, priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);
        //Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            priceToken0 * 10 ** (18 - decimals0), priceToken1 * 10 ** (18 - decimals1)
        );
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 0);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max && amount0 > 0);
        vm.assume(amount1 < type(uint104).max && amount1 > 0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)));

        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // amountOutA cannot exceed available liquidity.
        // Term (amount0 - 1) since amountOutB of second swap must be bigger as zero.
        amountOutA = bound(amountOutA, 1, amount0 - 1);

        // Do the first swap
        deal(address(token1), swapper, type(uint256).max);
        vm.startPrank(swapper);
        token1.approve(address(router), type(uint256).max);
        router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOutA,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );
        vm.stopPrank();

        // We want part of the fees in tokensOwed in this test -> we have to claim the pending fees.
        // To do this we decrease the position with minimal amount.
        vm.prank(liquidityProvider);
        uniV3.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: 1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint128).max
            })
        );

        // We do another swap from token1 to token0 -> start price cannot be the sqrtPriceLimitX96.
        (uint160 sqrtPrice_,,,,,,) = pool.slot0();
        vm.assume(sqrtPrice_ < 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341);
        // amountOutB cannot exceed remaining liquidity.
        amountOutB = bound(amountOutB, 1, amount0 - amountOutA);

        // Do the second swap
        vm.prank(swapper);
        router.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 100,
                recipient: swapper,
                deadline: type(uint160).max,
                amountOut: amountOutB,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341
            })
        );

        // Assert that the value of a position always statisfies: no_fees <= token_owed <= all_fees
        (uint256 actualValueInUsd,,,) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({ asset: address(uniV3), assetId: tokenId, assetAmount: 1, baseCurrency: 0 })
        );

        vm.prank(deployer);
        uniV3PricingModule.setFeeFlag(UniswapV3PricingModule.FeeFlag.TokensOwed);

        (uint256 actualValueInUsdTokenOwed,,,) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({ asset: address(uniV3), assetId: tokenId, assetAmount: 1, baseCurrency: 0 })
        );

        vm.prank(deployer);
        uniV3PricingModule.setFeeFlag(UniswapV3PricingModule.FeeFlag.All);

        (uint256 actualValueInUsdAll,,,) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({ asset: address(uniV3), assetId: tokenId, assetAmount: 1, baseCurrency: 0 })
        );

        assertGe(actualValueInUsdTokenOwed, actualValueInUsd);
        assertGe(actualValueInUsdAll, actualValueInUsdTokenOwed);
    }

    function testSuccess_getValue_RiskFactors(
        uint256 collFactor0,
        uint256 liqFactor0,
        uint256 collFactor1,
        uint256 liqFactor1
    ) public {
        liqFactor0 = bound(liqFactor0, 0, 100);
        collFactor0 = bound(collFactor0, 0, liqFactor0);
        liqFactor1 = bound(liqFactor1, 0, 100);
        collFactor1 = bound(collFactor1, 0, liqFactor1);

        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);
        uint256 tokenId = addLiquidity(pool, 1e5, liquidityProvider, 0, 10, true);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), 1);
        addUnderlyingTokenToArcadia(address(token1), 1);
        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        PricingModule.RiskVarInput[] memory riskVarInputs = new PricingModule.RiskVarInput[](2);
        riskVarInputs[0] = PricingModule.RiskVarInput({
            asset: address(token0),
            baseCurrency: 0,
            collateralFactor: uint16(collFactor0),
            liquidationFactor: uint16(liqFactor0)
        });
        riskVarInputs[1] = PricingModule.RiskVarInput({
            asset: address(token1),
            baseCurrency: 0,
            collateralFactor: uint16(collFactor1),
            liquidationFactor: uint16(liqFactor1)
        });
        vm.prank(deployer);
        standardERC20PricingModule.setBatchRiskVariables(riskVarInputs);

        uint256 expectedCollFactor = collFactor0 < collFactor1 ? collFactor0 : collFactor1;
        uint256 expectedLiqFactor = liqFactor0 < liqFactor1 ? liqFactor0 : liqFactor1;

        (,, uint256 actualCollFactor, uint256 actualLiqFactor) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({ asset: address(uniV3), assetId: tokenId, assetAmount: 1, baseCurrency: 0 })
        );

        assertEq(actualCollFactor, expectedCollFactor);
        assertEq(actualLiqFactor, expectedLiqFactor);
    }
}

/*///////////////////////////////////////////////////////////////
                    INTEGRATION TEST
///////////////////////////////////////////////////////////////*/
contract IntegrationTest is UniV3Test {
    using stdStorage for StdStorage;

    ERC20 usdc;
    ERC20 weth;

    // Before Each.
    function setUp() public override {
        super.setUp();
        vm.selectFork(fork);
    }

    function testSuccess_deposit(uint128 liquidity, int24 tickLower, int24 tickUpper) public {
        vm.startPrank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();

        vm.prank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        //usdc = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // dai
        weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        IUniswapV3PoolExtension pool = IUniswapV3PoolExtension(uniV3factory.getPool(address(usdc), address(weth), 100));
        (uint160 sqrtPriceX96, int24 tickCurrent,,,,,) = pool.slot0();

        // Check that ticks are within allowed ranges.
        tickLower = int24(bound(tickLower, tickCurrent - 16_095, tickCurrent + 16_095));
        tickUpper = int24(bound(tickUpper, tickCurrent - 16_095, tickCurrent + 16_095));
        // Ensure Tick is correctly spaced.
        {
            int24 tickSpacing = uniV3factory.feeAmountTickSpacing(pool.fee());
            tickLower = tickLower / tickSpacing * tickSpacing;
            tickUpper = tickUpper / tickSpacing * tickSpacing;
        }
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity > 10_000);
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, user, tickLower, tickUpper, false);

        // Warp 300 seconds to ensure that TWAT of 300s can be calculated (for some pools cardinality might be 1).
        vm.warp(block.timestamp + 300);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = uniV3.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );
        vm.assume(amount0 < type(uint128).max);
        vm.assume(amount1 < type(uint128).max);
        (uint256 amountUsdc, uint256 amountWeth) = usdc < weth ? (amount0, amount1) : (amount1, amount0);

        // Set max exposure to underlying tokens.
        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(usdc), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(weth), type(uint128).max);
        vm.stopPrank();

        vm.startPrank(user);
        address proxyAddr = factory.createVault(200, 0, address(0));
        Vault proxy = Vault(proxyAddr);
        //proxy.openTrustedMarginAccount(address(lendingPool));
        ERC721(address(uniV3)).approve(proxyAddr, tokenId);
        {
            address[] memory assetAddress = new address[](1);
            assetAddress[0] = address(uniV3);

            uint256[] memory assetId = new uint256[](1);
            assetId[0] = tokenId;

            uint256[] memory assetAmount = new uint256[](1);
            assetAmount[0] = 1;

            proxy.deposit(assetAddress, assetId, assetAmount);
        }
        vm.stopPrank();

        uint256 actualValue = proxy.getVaultValue(address(0));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(usdc);
        assetAddresses[1] = address(weth);

        uint256[] memory assetIds = new uint256[](2);

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountUsdc;
        assetAmounts[1] = amountWeth;

        uint256 expectedValue = mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, address(0));

        // Precision Chainlink oracles is often in the order of percentages.
        assertInRange(actualValue, expectedValue, 2);
    }
}
