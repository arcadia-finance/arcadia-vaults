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

    constructor(address _router) {
        UNISWAP_V2_ROUTER2 = _router;
    }

    function _uniswapV2Swap(
        address _to,
        uint256 _outgoingAssetAmount,
        uint256 _minIncomingAssetAmount,
        address[] memory _path
    ) internal {
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).swapExactTokensForTokens(
            _outgoingAssetAmount, _minIncomingAssetAmount, _path, _to, block.timestamp + 1
        );
    }

    function _uniswapV2AddLiquidity(
        address _recipient,
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal {
        //Approvals
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            _recipient,
            block.timestamp + 1
        );

    }

    function _uniswapV2RemoveLiquidity(
        address _recipient,
        address _poolToken,
        uint256 _poolTokenAmount,
        address _tokenA,
        address _tokenB,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal {
        //Approvals?
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).removeLiquidity(
            _tokenA, _tokenB, _poolTokenAmount, _amountAMin, _amountBMin, _recipient, block.timestamp + 1
        );
    }
}
