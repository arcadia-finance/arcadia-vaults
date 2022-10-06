/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

abstract contract UniswapV2Helper {
    address private immutable UNISWAP_V2_ROUTER2;

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
}
