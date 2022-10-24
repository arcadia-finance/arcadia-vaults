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
    constructor(address _router, address _mainreg) ActionBase(_mainreg) UniswapV2Helper(_router) {}

    function executeAction(address _vaultAddress, address _caller, bytes calldata _actionData)
        public
        override
        returns (actionAssetsData memory)
    {
        require(_vaultAddress == msg.sender, "UV2_SWAP: can only be called by vault");

        // preCheck data
        (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, address[] memory path) =
            _preCheck(_actionData);
        // execute Action
        _execute(_vaultAddress, _outgoing, _incoming, path);
        // postCheck data
        uint256[] memory _actualIncomingAssetsAmounts = _postCheck(_vaultAddress, _incoming);

        for (uint256 i; i < _incoming.assets.length;) {
            IERC20(_incoming.assets[i]).approve(_vaultAddress, type(uint256).max);
            
            unchecked {
                i++;
            }
        }

        _incoming.assetAmounts = _actualIncomingAssetsAmounts;

        return (_incoming);
    }

    function _execute(
        address _vaultAddress,
        actionAssetsData memory _outgoing,
        actionAssetsData memory _incoming,
        address[] memory path
    ) internal {
        _uniswapV2Swap(address(this), _outgoing.assetAmounts[0], _incoming.assetAmounts[0], path);
    }

    function _preCheck(bytes memory _actionSpecificData)
        internal
        view
        returns (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, address[] memory path)
    {
        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/

        (_outgoing, _incoming, path) = abi.decode(_actionSpecificData, (actionAssetsData, actionAssetsData, address[]));

        require(path.length >= 2, "UV2A_SWAP: _path must be >= 2");

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        //Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(_incoming.assets, _incoming.assetIds),
            "UV2A_SWAP: Non-allowlisted incoming asset"
        );

        return (_outgoing, _incoming, path);
    }

    function _postCheck(address _vaultAddress, actionAssetsData memory incomingAssets_)
        internal
        view
        returns (uint256[] memory incomingAssetAmounts_)
    {
        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        uint256 incomingLength = incomingAssets_.assets.length;
        incomingAssetAmounts_ = new uint256[](incomingLength);
        for (uint256 i; i < incomingLength;) {
            incomingAssetAmounts_[i] =
                IERC20(incomingAssets_.assets[i]).balanceOf(address(this)) - incomingAssets_.preActionBalances[i];

            // Check incoming assets are as expected
            require(
                incomingAssetAmounts_[i] >= incomingAssets_.assetAmounts[i],
                "UV2A_SWAP: Received incoming asset less than expected"
            );
            unchecked {
                i++;
            }
        }

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        // outgoingAssetAmounts_ = new uint256[](outgoingAssets_.assets.length);
        // for (uint256 i; i < outgoingAssets_.assets.length; i++) {
        //     // Calculate the balance change of outgoing assets. Ignore if balance increased.
        //     uint256 postActionBalances = IERC20(outgoingAssets_.assets[i]).balanceOf(_vaultAddress);
        //     if (postActionBalances < outgoingAssets_.preActionBalances[i]) {
        //         outgoingAssetAmounts_[i] = outgoingAssets_.preActionBalances[i] - postActionBalances;
        //     }

        //     //Check outgoing assets are as expected
        //     require(
        //         outgoingAssetAmounts_[i] <= outgoingAssets_.assetAmounts[i],
        //         "UV2A_SWAP: Outgoing amount greater than expected"
        //     );
        // }

        return incomingAssetAmounts_;
    }
}
