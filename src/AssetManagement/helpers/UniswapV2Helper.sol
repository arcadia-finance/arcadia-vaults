/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/IUniswapV2Router02.sol";

abstract contract UniswapV2Helper {
    address public immutable UNISWAP_V2_ROUTER2;

    constructor(address router) {
        UNISWAP_V2_ROUTER2 = router;
    }

    function _uniswapV2Swap(
        address to,
        uint256 outgoingAssetAmount,
        uint256 minIncomingAssetAmount,
        address[] memory path
    ) internal {
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).swapExactTokensForTokens(
            outgoingAssetAmount, minIncomingAssetAmount, path, to, block.timestamp + 1
        );
    }

    function _uniswapV2AddLiquidity(
        address recipient,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal {
        //Approvals
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).addLiquidity(
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, recipient, block.timestamp + 1
        );
    }

    function _uniswapV2RemoveLiquidity(
        address recipient,
        address _poolToken,
        uint256 poolTokenAmount,
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal {
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).removeLiquidity(
            tokenA, tokenB, poolTokenAmount, amountAMin, amountBMin, recipient, block.timestamp + 1
        );
    }
}
