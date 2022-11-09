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
        address pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                uv2Factory,
                keccak256(abi.encodePacked(tokenA, tokenB)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));

  
        doAllStdStores(tokenA, tokenB, amountAMin, amountBMin, pair);

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
        address pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                uv2Factory,
                keccak256(abi.encodePacked(_tokenA, _tokenB)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))) ));

        {
        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token0.selector).with_key(address(msg.sender)).checked_write(
            IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

        stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(pair))
            .checked_write(IERC20(_tokenA).balanceOf(pair) - _amountAMin);

        //Cheat balance of
        stdstore.target(address(pair)).sig(IUniswapV2Pair(pair).token1.selector).with_key(address(msg.sender)).checked_write(
            IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

        stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(pair))
            .checked_write(IERC20(_tokenB).balanceOf(pair) - _amountBMin);
        }

        return (_amountAMin, _amountBMin);
    }

    function doAllStdStores(address _tokenA, address _tokenB, uint256 _amountAMin, uint256 _amountBMin, address pair) public {
                //Cheat balance of
        stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenA).balanceOf(msg.sender) + _amountAMin);

        stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(msg.sender))
            .checked_write(IERC20(_tokenB).balanceOf(msg.sender) + _amountBMin);

          {
            stdstore.target(address(pair)).sig(IUniswapV2Pair(address(pair)).token0.selector).with_key(address(msg.sender)).checked_write(
                _amountAMin
            );
    }
    {
            stdstore.target(address(_tokenA)).sig(IERC20(_tokenA).balanceOf.selector).with_key(address(pair))
                .checked_write(IERC20(_tokenA).balanceOf(address(pair)) + _amountAMin);
    }
    {       //Cheat balance of
            stdstore.target(address(pair)).sig(IUniswapV2Pair(address(pair)).token1.selector).with_key(address(msg.sender)).checked_write(
                _amountBMin
            );
    }
    {
            stdstore.target(address(_tokenB)).sig(IERC20(_tokenB).balanceOf.selector).with_key(address(pair))
                .checked_write(IERC20(_tokenB).balanceOf(address(pair)) + _amountBMin);

    }

    }
}
