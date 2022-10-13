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
        uint256 slot = stdstore.target(address(path[0])).sig(IERC20(path[0]).balanceOf.selector).with_key(
            address(msg.sender)
        ).find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedBalanceOf = bytes32(abi.encode(123));
        vm.store(address(path[0]), loc, mockedBalanceOf);

        //Cheat balance of
        uint256 slot2 =
            stdstore.target(address(path[1])).sig(IERC20(path[1]).balanceOf.selector).with_key(address(to)).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf2 = bytes32(abi.encode(amountOutMin));
        vm.store(address(path[1]), loc2, mockedBalanceOf2);
    }
}
