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
    ) external virtual returns (uint256[] memory amounts) {
        // get address of the uniswap pair for the two tokens
        address pair = IUniswapV2Factory(uv2Factory).getPair(tokenA, tokenB);
        console.log("pair address: ", pair);

        //doAllAddStdStores(tokenA, tokenB, amountAMin, amountBMin, address(pair));
        UniswapV2PairMock(pair).mint(to, amountADesired, amountBDesired);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountADesired;
        amounts[1] = amountBDesired;

        return amounts;
    }

    function removeLiquidity(
        address _recipient,
        address _poolToken,
        uint256 _poolTokenAmount,
        address _tokenA,
        address _tokenB,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external virtual returns (uint256 amountA, uint256 amountB) {
        //get pair address
        // get address of the uniswap pair for the two tokens
        address pair = IUniswapV2Factory(uv2Factory).getPair(_tokenA, _tokenB);

        {
            //Cheat balance of
            stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token0.selector).with_key(address(msg.sender))
                .checked_write(IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

            stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(pair))
                .checked_write(IERC20(_tokenA).balanceOf(pair) - _amountAMin);

            //Cheat balance of
            stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token1.selector).with_key(address(msg.sender))
                .checked_write(IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

            stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(pair))
                .checked_write(IERC20(_tokenB).balanceOf(pair) - _amountBMin);
        }

        return (_amountAMin, _amountBMin);
    }

    function doAllAddStdStores(address _tokenA, address _tokenB, uint256 _amountAMin, uint256 _amountBMin, address pair)
        public
    {
        //Cheat balance of actionHandler on tokenA -> remove balance
        stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenA).balanceOf(msg.sender) - _amountAMin);

        //Cheat balance of actionHandler on tokenB -> remove balance
        stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenB).balanceOf(msg.sender) - _amountBMin);

        // //Cheat reserve of tokenA on pair
        // stdstore.target(address(pair)).sig(IUniswapV2Pair(address(pair)).reserve0.selector)
        //     .checked_write(_amountAMin);
        // console.log("reserve0: ", IUniswapV2Pair(address(pair)).reserve0());


        // //Cheat reserve of reserveB on pair
        // stdstore.target(address(pair)).sig(IUniswapV2Pair(address(pair)).reserve1.selector)
        //     .checked_write(_amountBMin);

        // console.log("reserve1: ", IUniswapV2Pair(address(pair)).reserve1());

        //Cheat balance of pair on tokenA
        stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(pair)).checked_write(
            IERC20(_tokenA).balanceOf(address(pair)) + _amountAMin
        );

        //Cheat balance of pair on tokenB
        stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(pair)).checked_write(
            IERC20(_tokenB).balanceOf(address(pair)) + _amountBMin
        );

        //Cheat balance of actionHandler on pair
        stdstore.target(address(pair)).sig(IERC20(address(pair)).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(_amountBMin);
    }

}
