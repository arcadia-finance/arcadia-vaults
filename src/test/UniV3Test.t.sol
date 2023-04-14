/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";
import "../PricingModules/UniswapV3/UniswapV3PricingModule.sol";

contract UniV3Test is Test {
    UniV3PriceModule uniV3PriceModule;

    // function setUp() public {
    //     uniV3PriceModule = new UniV3PriceModule();
    // }
    // // function testValuesV3() public {
    // //     (address _token0,address _token1,uint24 _fee,uint256 _amount0,uint256 _amount1) = uniV3PriceModule._getNFTAmounts(351451);
    // // }

    // // function testGetPos() public {
    // //     (uint96 __nonce,
    // //         address __operator,
    // //         address __token0,
    // //         address __token1,
    // //         uint24 __fee,
    // //         int24 __tickLower,
    // //         int24 __tickUpper,
    // //         uint128 __liquidity,
    // //         uint256 __feeGrowthInside0LastX128,
    // //         uint256 __feeGrowthInside1LastX128,
    // //         uint128 __tokensOwed0,
    // //         uint128 __tokensOwed1
    // //     ) = uniV3PriceModule.getPos(1105);
    // // }

    // function testdostuff() public {
    //     (
    //         ,
    //         ,
    //         address token0,
    //         address token1,
    //         uint24 fee,
    //         int24 tickLower,
    //         int24 tickUpper,
    //         uint128 liquidity,
    //         uint256 positionFeeGrowthInside0LastX128,
    //         uint256 positionFeeGrowthInside1LastX128,
    //         uint256 tokensOwed0,
    //         uint256 tokensOwed1
    //     ) = uniV3PriceModule.nonfungiblePositionManager().positions(9814);

    //     emit log_named_address("token0", token0);
    //     emit log_named_address("token1", token1);
    //     emit log_named_uint("fee", fee);
    //     emit log_named_int("tickLower", tickLower);
    //     emit log_named_int("tickUpper", tickUpper);
    //     emit log_named_uint("liquidity", liquidity);
    //     emit log_named_uint("positionFeeGrowthInside0LastX128", positionFeeGrowthInside0LastX128);
    //     emit log_named_uint("positionFeeGrowthInside1LastX128", positionFeeGrowthInside1LastX128);
    //     emit log_named_uint("tokensOwed0", tokensOwed0);
    //     emit log_named_uint("tokensOwed1", tokensOwed1);

    //     IUniswapV3Factory uniswapV3Factory = uniV3PriceModule.uniswapV3Factory();
    //     IUniswapV3Pool _uniswapV3Pool = IUniswapV3Pool(uniswapV3Factory.getPool(token0, token1, fee));
    //     (, int24 poolTick,,,,,) = _uniswapV3Pool.slot0();
    //     emit log_named_int("poolTick", poolTick);

    //     uint160 _sqrtRatioX96 = TickMath.getSqrtRatioAtTick(poolTick);
    //     emit log_named_uint("sqrtRatioX96", _sqrtRatioX96);
    // }
}
