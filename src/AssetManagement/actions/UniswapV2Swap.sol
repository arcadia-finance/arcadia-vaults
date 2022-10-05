/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../ActionBase.sol";
import "../helpers/UniswapV2Helper.sol";

contract UniswapV2SwapAction is ActionBase, UniswapV2Helper {
    constructor(address _router)
        UniswapV2Helper(_router)
    {}

    function executeAction(address _vaultAddress, bytes calldata _actionData)
        public
    {
    
    // Decode data
     (uint256 outgoingAssetAmount, uint256 minIncomingAssetAmount, address[]memory path) = abi.decode(_actionData, (uint256, uint256, address[])) ;
    // preCheck data
    // manage approvals
    // execute Action
    _execute(_vaultAddress, outgoingAssetAmount, minIncomingAssetAmount, path);

    }


    function _execute(address _vaultAddress, uint256 outgoingAssetAmount, uint256 minIncomingAssetAmount, address[] memory path) private {
            _uniswapV2Swap(_vaultAddress, outgoingAssetAmount, minIncomingAssetAmount, path);

    }

}
