// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IUniswapV3Pool } from "../../PricingModules/UniswapV3/interfaces/IUniswapV3Pool.sol";

interface IUniswapV3PoolExtension is IUniswapV3Pool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    function maxLiquidityPerTick() external view returns (uint128 maxLiquidityPerTick);
}
