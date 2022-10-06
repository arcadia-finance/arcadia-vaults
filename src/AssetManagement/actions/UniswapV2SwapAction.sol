/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../ActionBase.sol";
import "../helpers/UniswapV2Helper.sol";
import "../utils/ActionAssetData.sol";
import "../../interfaces/IMainRegistry.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IERC20.sol";

contract UniswapV2SwapAction is ActionBase, UniswapV2Helper {
    //Maybe add mainreg address also here
    constructor(address _router, address _mainreg) ActionBase(_mainreg) UniswapV2Helper(_router) {}

    function executeAction(bytes calldata _actionData) override public {
        // decode action data
        (address _vaultAddress, address _caller, bytes memory _actionSpecificData) =
            abi.decode(_actionData, (address, address, bytes));
        // preCheck data
        (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, address[] memory path) = _preCheck(_vaultAddress, _actionSpecificData);
        // execute Action
         _execute(_vaultAddress, _outgoing, _incoming, path);
        // postCheck data
        _postCheck();
        // revoke approvals
        // IVault -> revoke approval for action
    }

    function _execute(
        address _vaultAddress,
        actionAssetsData memory _outgoing,
        actionAssetsData memory _incoming,
        address[] memory path
    ) private {
                 _uniswapV2Swap(_vaultAddress, _outgoing.assetAmounts[0], _incoming.assetAmounts[0], path);
    }

    function _preCheck(address _vaultAddress, bytes memory _actionSpecificData)
        private
        returns (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, address[] memory path)
    {
        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/

        (_outgoing, _incoming, path) = abi.decode(_actionSpecificData, (actionAssetsData, actionAssetsData, address[]));

        require(path.length >= 2, "UV2A_SWAP: _path must be >= 2");

        // Check if inputs are correct
        require(_outgoing.assets.length == _outgoing.assetAmounts.length, "UV2_SWAP: Outgoing assets arrays unequal");
        require(_outgoing.assets.length == _outgoing.assetIds.length, "UV2_SWAP: Outgoing assets arrays unequal");
        
        require(_incoming.assets.length == _incoming.assetAmounts.length, "UV2_SWAP: Incoming assets arrays unequal");
        require(_incoming.assets.length == _incoming.assetIds.length, "UV2_SWAP: Incoming assets arrays unequal");

        //Moar tests?


        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        for (uint256 i; i < _outgoing.assets.length; i++) {
            _outgoing.preActionBalances[i] = IERC20(path[0]).balanceOf(_vaultAddress);
            IVault(_vaultAddress).approveAssetForActionHandler(address(this), _outgoing.assets[0], _outgoing.assetAmounts[i]);
        }

        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        // Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(_incoming.assets, _incoming.assetIds),
            "UV2A_SWAP: Non-whitelisted incoming asset"
        );

        for (uint256 i; i < _incoming.assets.length; i++) {
            _incoming.preActionBalances[i] = IERC20(path[0]).balanceOf(_vaultAddress);
        }

        return (_outgoing, _incoming, path);
    }

    function _postCheck() private {
        //post checks on vault
    }
}
