/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import { DeployedContracts } from "./fixtures/DeployedContracts.f.sol";
import { ERC20Fixture } from "./fixtures/ERC20Fixture.f.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { UniswapV3PricingModule, TickMath } from "../PricingModules/UniswapV3/UniswapV3PricingModule.sol";
import { INonfungiblePositionManagerExtension } from "./interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from "./interfaces/IUniswapV3PoolExtension.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { LiquidityAmountsExtension } from "./libraries/LiquidityAmountsExtension.sol";

contract UniswapV3PricingModuleExtension is UniswapV3PricingModule {
    constructor(address mainRegistry_, address oracleHub_, address riskManager_, address erc20PricingModule_)
        UniswapV3PricingModule(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_)
    { }

    function getTickTwap(IUniswapV3PoolExtension pool) external view returns (int24 tick) {
        return _getTickTwap(pool);
    }
}

abstract contract UniV3Test is DeployedContracts, Test {
    string RPC_URL = vm.envString("RPC_URL");
    uint256 fork;

    address public liquidityProvider = address(1);
    address public swapper = address(2);

    UniswapV3PricingModuleExtension uniV3PricingModule;
    INonfungiblePositionManagerExtension public uniV3 =
        INonfungiblePositionManagerExtension(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory public uniV3factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    ERC20Fixture erc20Fixture;

    event RiskManagerUpdated(address riskManager);

    //this is a before
    constructor() {
        fork = vm.createFork(RPC_URL);

        erc20Fixture = new ERC20Fixture();
        vm.makePersistent(address(erc20Fixture));
    }

    //this is a before each
    function setUp() public virtual { }
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

    function testRevert_addAsset_NonUniswapV3PositionManager(address badAddress) public {
        // badAddress cannot be a contract with a function: factory()
        (bool success,) = badAddress.call(abi.encodeWithSignature("factory()"));
        vm.assume(success == false);

        vm.startPrank(deployer);
        vm.expectRevert();
        uniV3PricingModule.addAsset(badAddress);
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

        address factory = uniV3.factory();
        assertTrue(uniV3PricingModule.inPricingModule(address(uniV3)));
        assertEq(uniV3PricingModule.assetsInPricingModule(0), address(uniV3));
        assertEq(uniV3PricingModule.assetToV3Factory(address(uniV3)), factory);
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

        // Set an allowed exposure for tokenA and tokenB greater than 0.
        vm.startPrank(deployer);
        uniV3PricingModule.setExposureOfAsset(address(tokenA), maxExposureA);
        uniV3PricingModule.setExposureOfAsset(address(tokenB), maxExposureB);
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
        (token0, token1) = token0 < token1 ? (token0, token1) : (token0, token1);
        address poolAddress =
            uniV3.createAndInitializePoolIfNecessary(address(token0), address(token1), 100, 4_295_128_739); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(300);
    }

    // Helper function.
    function isBelowMaxLiquidityPerTick(
        int24 tickLower,
        int24 tickHigher,
        uint256 amount0,
        uint256 amount1,
        IUniswapV3PoolExtension pool_
    ) public view returns (bool) {
        (uint160 sqrtPrice,,,,,,) = pool_.slot0();

        uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickHigher), amount0, amount1
        );

        return liquidity <= pool_.maxLiquidityPerTick();
    }

    function testSuccess_getTickTwap(
        uint256 timePassed,
        int24 tickLower,
        int24 tickHigher,
        uint64 amount0Initial,
        uint64 amountOut0,
        uint64 amountOut1
    ) public {
        vm.assume(tickLower < tickHigher);
        // Check that ticks are within allowed ranges
        int24 MIN_TICK = -887_272;
        int24 MAX_TICK = -MIN_TICK;
        vm.assume(
            (tickLower < 0 ? uint256(-int256(tickLower)) : uint256(int256(tickLower))) <= uint256(uint24(MAX_TICK))
        );
        vm.assume(
            (tickHigher < 0 ? uint256(-int256(tickHigher)) : uint256(int256(tickHigher))) <= uint256(uint24(MAX_TICK))
        );
        // Avoid rounding to 0
        vm.assume(amountOut0 > 1e2);
         // Avoid rounding to 0
        vm.assume(amountOut1 > 1e2);
        // Total amountOut must be smaller as initial Liquidity.
        // Term 1e2: Avoid that full liquidity is almost swapped out since this would bring sqrtPriceLimitX96 to TickMath.MAX_SQRT_RATIO resulting in 'SPL'.
        vm.assume(uint256(amountOut0) + amountOut1 + 1e2 < amount0Initial);
        vm.assume(isBelowMaxLiquidityPerTick(tickLower, tickHigher, amount0Initial, 0, pool));
        // Limit timePassed between the two swaps to 300s (the TWAP duration).
        timePassed = bound(timePassed, 0, 300);

        // Provide liquidity only in token0
        deal(address(token0), liquidityProvider, amount0Initial);
        vm.startPrank(liquidityProvider);
        token0.approve(address(uniV3), type(uint256).max);
        uniV3.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 100,
                tickLower: tickLower,
                tickUpper: tickHigher,
                amount0Desired: amount0Initial,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        // Do a first swap
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

        // Calculate the TWAP 300s after the first swap.
        vm.warp(timestamp + 300);
        int256 expectedTickTwap =
            (int256(tick0) * int256(timePassed) + int256(tick1) * int256((300 - timePassed))) / 300;

        // Compare with the actual TWAP.
        int256 actualTickTwap = uniV3PricingModule.getTickTwap(pool);
        assertEq(actualTickTwap, expectedTickTwap);
    }
}
