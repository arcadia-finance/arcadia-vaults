/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";

import "../../lib/forge-std/src/Test.sol";


contract UniswapV2Router02Mock is Test {
    using stdStorage for StdStorage;

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
        //Cheat balance of
        stdstore.target(address(tokenA)).sig(IERC20(tokenA).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(tokenA).balanceOf(msg.sender) - amountADesired);

        stdstore.target(address(tokenB)).sig(IERC20(tokenB).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(tokenB).balanceOf(msg.sender) - amountBDesired);

        // get address of the uniswap pair for the two tokens
        // we assume this is the tests
        address pair = address(10);

        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token0.selector).with_key(address(msg.sender)).checked_write(
            amountAMin
        );
        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token1.selector).with_key(address(msg.sender)).checked_write(
            amountBMin
        );

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
        //Cheat balance of
        stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenA).balanceOf(msg.sender) + _amountAMin);

        stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

        //get pair address
        address pair = address(10);

        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token0.selector).with_key(address(msg.sender)).checked_write(
            0
        );
        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token1.selector).with_key(address(msg.sender)).checked_write(
            0
        );

        return (_amountAMin, _amountBMin);
    }
}
