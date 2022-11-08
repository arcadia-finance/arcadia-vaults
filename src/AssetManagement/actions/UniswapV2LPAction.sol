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

contract UniswapV2LPAction is ActionBase, UniswapV2Helper {
    constructor(address _router, address _mainreg) ActionBase(_mainreg) UniswapV2Helper(_router) {}

    function executeAction(address _vaultAddress, bytes calldata _actionData)
        public
        override
        returns (actionAssetsData memory)
    {
        require(_vaultAddress == msg.sender, "UV2_LP: can only be called by vault");
        // preCheck data
        (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, bytes4 _selector) =
            _preCheck(_actionData);
        // execute Action
        _execute(_outgoing, _incoming, _selector);
        // postCheck data
        uint256[] memory _actualIncomingAssetsAmounts = _postCheck(_incoming);

        for (uint256 i; i < _incoming.assets.length;) {
            IERC20(_incoming.assets[i]).approve(_vaultAddress, type(uint256).max);
            unchecked {
                i++;
            }
        }
        _incoming.assetAmounts = _actualIncomingAssetsAmounts;

        return (_incoming);
    }

    function _execute(actionAssetsData memory _outgoing, actionAssetsData memory _incoming, bytes4 _selector)
        internal
    {
        
        if (_selector == bytes4(keccak256("add"))) {
            _uniswapV2AddLiquidity(
                address(this), // recipient
                _outgoing.assets[0], // tokenA
                _outgoing.assets[1], /// tokenB
                _outgoing.assetAmounts[0], // amountADesired
                _outgoing.assetAmounts[1], // amountBDesired
                _outgoing.assetAmounts[0], // amountAMin
                _outgoing.assetAmounts[1]  // amountBMin
            ); //TODO: min amounts?
        } else if (_selector == bytes4(keccak256("remove"))) {
            _uniswapV2RemoveLiquidity(
                address(this),
                _outgoing.assets[0],
                _outgoing.assetAmounts[0],
                _incoming.assets[0],
                _incoming.assets[1],
                _incoming.assetAmounts[0],
                _incoming.assetAmounts[1]
            );
        }

        //require(_incoming.assets.length == _incoming.assetAmounts.length, "UV2A_LP: _incoming assets and amounts length mismatch");
    }

    function _preCheck(bytes memory _actionSpecificData)
        internal
        view
        returns (actionAssetsData memory _outgoing, actionAssetsData memory _incoming, bytes4 _selector)
    {
        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/

        (_outgoing, _incoming, _selector) =
            abi.decode(_actionSpecificData, (actionAssetsData, actionAssetsData, bytes4));

        if (_selector == bytes4(keccak256("add"))) {
            require(_outgoing.assets.length >= 2, "UV2A_LP: Need atleast two base tokens");
            require(_incoming.assets.length == 1, "UV2A_LP: Can only out one lp token");
        } else if (_selector == bytes4(keccak256("remove"))) {
            require(_outgoing.assets.length >= 1, "UV2A_LP: Can only out one lp token");
            require(_incoming.assets.length == 2, "UV2A_LP: Need atleast two base tokens");
        }

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

        return (_outgoing, _incoming, _selector);
    }

    function _postCheck(actionAssetsData memory incomingAssets_)
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

        return incomingAssetAmounts_;
    }
}
