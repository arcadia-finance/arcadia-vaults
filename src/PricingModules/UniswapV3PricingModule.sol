/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { PricingModule } from "./AbstractPricingModule.sol";
import {INonfungiblePositionManager} from './interfaces/INonfungiblePositionManager.sol';
import {IUniswapV3Factory} from './interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool} from './interfaces/IUniswapV3Pool.sol';
import { TickMath } from '../utils/TickMath.sol';
import { LiquidityAmounts } from '../utils/LiquidityAmounts.sol';

contract UniV3PriceModule is PricingModule {

    INonfungiblePositionManager public nonfungiblePositionManager;
    IUniswapV3Factory public uniswapV3Factory;

    constructor (address mainRegistry_, address oracleHub_, address riskManager_) PricingModule(mainRegistry_, oracleHub_, 1, riskManager_) {
        nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
         {}
    }

    struct FeeParams {
            address token0;
            address token1;
            uint24 fee;
            int24 tickLower;
            int24 tickUpper;
            uint128 liquidity;
            uint256 positionFeeGrowthInside0LastX128;
            uint256 positionFeeGrowthInside1LastX128;
            uint256 tokensOwed0;
            uint256 tokensOwed1;
        }

    struct Position {
            uint96 nonce;
            address operator;
            address token0;
            address token1;
            uint24 fee;
            int24 tickLower;
            int24 tickUpper;
            uint128 liquidity;
            uint256 positionFeeGrowthInside0LastX128;
            uint256 positionFeeGrowthInside1LastX128;
            uint256 tokensOwed0;
            uint256 tokensOwed1;
        }

    function _getNFTAmounts(uint256 tokenId) public view returns(Position memory position, uint256 amount0, uint256 amount1){
        // (,,token0,token1,fee,tickLower,tickUpper,liquidity,positionFeeGrowthInside0LastX128,positionFeeGrowthInside1LastX128,tokensOwed0,tokensOwed1) = nonfungiblePositionManager.positions(_tokenId);
        position = getPos(tokenId);
        IUniswapV3Pool _uniswapV3Pool = IUniswapV3Pool(uniswapV3Factory.getPool(position.token0,position.token1,position.fee));
        (,int24 poolTick,,,,,) = _uniswapV3Pool.slot0();
        uint160 _sqrtRatioX96 = TickMath.getSqrtRatioAtTick(poolTick);
        uint160 _sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(position.tickLower);
        uint160 _sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(position.tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(_sqrtRatioX96,_sqrtRatioAX96,_sqrtRatioBX96,position.liquidity);
    }

    function getPos(uint256 tokenId) public view returns (
            Position memory pos
        ) {
        (, 
        , 
        pos.token0, 
        pos.token1, 
        pos.fee, 
        pos.tickLower, 
        pos.tickUpper, 
        pos.liquidity, 
        pos.positionFeeGrowthInside0LastX128, 
        pos.positionFeeGrowthInside1LastX128, 
        , 
        ) = nonfungiblePositionManager.positions(tokenId);
        return pos;
    }
}
