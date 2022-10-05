/**
 * This is a private, unpublished repository.
 * All rights reserved to Arcadia Finance.
 * Any modification, publication, reproduction, commercialization, incorporation,
 * sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
 *
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

interface IUniswapV2Router02 {
      function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}


