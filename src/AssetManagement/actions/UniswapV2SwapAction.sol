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
    constructor(address router, address mainreg) ActionBase(mainreg) UniswapV2Helper(router) {}

    function executeAction(address vaultAddress, bytes calldata actionData)
        public
        override
        returns (actionAssetsData memory)
    {
        require(vaultAddress == msg.sender, "UV2_SWAP: can only be called by vault");
        // preCheck data
        (actionAssetsData memory outgoing, actionAssetsData memory incoming, address[] memory path) =
            _preCheck(actionData);
        // execute Action
        _execute(outgoing, incoming, path);
        // postCheck data
        incoming.assetAmounts = _postCheck(incoming);

        for (uint256 i; i < incoming.assets.length;) {
            IERC20(incoming.assets[i]).approve(vaultAddress, type(uint256).max);
            unchecked {
                i++;
            }
        }

        return (incoming);
    }

    function _execute(actionAssetsData memory outgoing, actionAssetsData memory incoming, address[] memory path)
        internal
    {
        _uniswapV2Swap(address(this), outgoing.assetAmounts[0], incoming.assetAmounts[0], path);
    }

    function _preCheck(bytes memory actionSpecificData)
        internal
        view
        returns (actionAssetsData memory outgoing, actionAssetsData memory incoming, address[] memory path)
    {
        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/

        (outgoing, incoming, path) = abi.decode(actionSpecificData, (actionAssetsData, actionAssetsData, address[]));

        require(path.length >= 2, "UV2A_SWAP: _path must be >= 2");

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        //Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(incoming.assets, incoming.assetIds),
            "UV2A_SWAP: Non-allowlisted incoming asset"
        );

        return (outgoing, incoming, path);
    }

    function _postCheck(actionAssetsData memory incomingAssets)
        internal
        pure
        returns (uint256[] memory incomingAssetAmounts)
    {
        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        return incomingAssets.assetAmounts;
    }
}
