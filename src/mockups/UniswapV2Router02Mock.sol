/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";

import "../../lib/forge-std/src/Test.sol";
import "../mockups/UniswapV2PairMock.sol";

contract UniswapV2Router02Mock is Test {
    using stdStorage for StdStorage;

    address uv2Factory;

    constructor(address factory) {
        uv2Factory = factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual returns (uint256[] memory amounts) {
        //Cheat balance of
        stdstore.target(address(path[0])).sig(IERC20(path[0]).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(path[0]).balanceOf(msg.sender) - amountIn);

        stdstore.target(address(path[1])).sig(IERC20(path[1]).balanceOf.selector).with_key(address(to)).checked_write(
            amountOutMin
        );

        return amounts;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual returns (uint256[] memory amounts, uint256 liquidity) {
        // get address of the uniswap pair for the two tokens
        address pair = IUniswapV2Factory(uv2Factory).getPair(tokenA, tokenB);

        ERC20(tokenA).transferFrom(msg.sender, pair, amountAMin);
        ERC20(tokenB).transferFrom(msg.sender, pair, amountBMin);
        require(ERC20(tokenA).balanceOf(pair) >= amountAMin, "ERC20: transfer amount exceeds balance");
        require(ERC20(tokenB).balanceOf(pair) >= amountBMin, "ERC20: transfer amount exceeds balance");
        liquidity = UniswapV2PairMock(pair).mint(to, amountAMin, amountBMin);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountADesired;
        amounts[1] = amountBDesired;

        return (amounts, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual returns (uint256 amountA, uint256 amountB) {
        // get address of the uniswap pair for the two tokens
        address pair = IUniswapV2Factory(uv2Factory).getPair(tokenA, tokenB);

        UniswapV2PairMock(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = UniswapV2PairMock(pair).burn(to);
        (amountA, amountB) = (amount0, amount1);

        require(amountA >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");

        return (amountA, amountB);
    }
}
