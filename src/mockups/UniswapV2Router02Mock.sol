/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../interfaces/IERC20.sol";

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
    }
}
