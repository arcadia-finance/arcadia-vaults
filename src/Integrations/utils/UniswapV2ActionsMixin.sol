// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./AssetHelpers.sol";

/// @title UniswapV2ActionsMixin Contract
/// @author Enzyme Council <security@enzyme.finance>
/// @notice Mixin contract for interacting with Uniswap v2
abstract contract UniswapV2ActionsMixin is AssetHelpers {
    address private immutable UNISWAP_V2_ROUTER2;

    constructor(address _router) {
        UNISWAP_V2_ROUTER2 = _router;
    }

    /// @dev Helper to execute a swap
    function __uniswapV2Swap(
        address _recipient,
        uint256 _outgoingAssetAmount,
        uint256 _minIncomingAssetAmount,
        address[] memory _path
    ) internal {
        __approveAssetMaxAsNeeded(_path[0], UNISWAP_V2_ROUTER2, _outgoingAssetAmount);

        // Execute fill
        IUniswapV2Router02(UNISWAP_V2_ROUTER2).swapExactTokensForTokens(
            _outgoingAssetAmount, _minIncomingAssetAmount, _path, _recipient, __uniswapV2GetActionDeadline()
        );
    }

    /// @dev Helper to get the deadline for a Uniswap V2 action in a standardized way
    function __uniswapV2GetActionDeadline() private view returns (uint256 deadline_) {
        return block.timestamp + 1;
    }

    ///////////////////
    // STATE GETTERS //
    ///////////////////

    /// @notice Gets the `UNISWAP_V2_ROUTER2` variable
    /// @return router_ The `UNISWAP_V2_ROUTER2` variable value
    function getUniswapV2Router2() public view returns (address router_) {
        return UNISWAP_V2_ROUTER2;
    }
}
