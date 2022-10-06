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
    constructor(address _router, address _mainreg)
        ActionBase(_mainreg)
        UniswapV2Helper(_router)
    {}

    function executeAction(bytes calldata _actionData)
        public
    {
    // decode action data
     (address _vaultAddress, address _caller, bytes memory _actionSpecificData) = abi.decode(_actionData, (address, address, bytes));
    // preCheck data --> returns some stuff too?
    (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, address[] memory path) = _preCheck();
    // manage approvals
    IVault(_vaultAddress).approveAssetForActionHandler(
                address(this), path[0], path[path.length - 1]
    );
    // execute Action
    _execute(_actionSpecificData);
    // postCheck data
    _postCheck();
    // revoke approvals
    // IVault -> revoke approval for action
    }

    function _execute(address _vaultAddress, uint256 outgoingAssetAmount, uint256 minIncomingAssetAmount, address[] memory path) private {
            _uniswapV2Swap(_vaultAddress, outgoingAssetAmount, minIncomingAssetAmount, path);
    }

    function _preCheck(address _vaultAddress, bytes memory _actionSpecificData) 
        private
        returns (
            actionAssetsData memory _outgoing,
            actionAssetsData memory _incoming,
            address[] memory path
        ) {


        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/

        (_outgoing, _incoming,path) = abi.decode(_actionSpecificData, (actionAssetsData, actionAssetsData, address[]));

        require(path.length >= 2, "UV2A_SWAP: _path must be >= 2");


        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        _outgoing.preActionBalance = IERC20(path[0]).balanceOf(_vaultAddress);
        IVault(_vaultAddress).approveAssetForAction(
                    address(this), path[0], _outgoing.assetAmounts
        );
     
        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        // Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(_incoming.assets, _incoming.assetIds),
            "UV2A_SWAP: Non-whitelisted incoming asset"
        );

        _incoming.preActionBalance = IERC20(path[path.length -1]).balanceOf(_vaultAddress);
       

        return (_outgoing, _incoming, path);
    }

    function _postCheck() private {
        //post checks on vault
    }

}
