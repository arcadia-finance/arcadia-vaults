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
    constructor(address router, address mainreg) ActionBase(mainreg) UniswapV2Helper(router) {}

    function executeAction(address vaultAddress, bytes calldata actionData)
        public
        override
        returns (actionAssetsData memory)
    {
        require(vaultAddress == msg.sender, "UV2_LP: can only be called by vault");
        // preCheck data
        (actionAssetsData memory outgoing, actionAssetsData memory incoming, bytes4 selector) =
            _preCheck(actionData);
        // execute Action
        _execute(outgoing, incoming, selector);
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

    function _execute(actionAssetsData memory outgoing, actionAssetsData memory incoming, bytes4 selector)
        internal
    {
        require(
            bytes4(selector) == bytes4(keccak256("remove")) || bytes4(selector) == bytes4(keccak256("add")),
            "UV2A_LP: invalid selector"
        );

        if (bytes4(selector) == bytes4(keccak256("add"))) {
            _uniswapV2AddLiquidity(
                address(this), // recipient
                outgoing.assets[0], // tokenA
                outgoing.assets[1],
                /// tokenB
                outgoing.assetAmounts[0], // amountADesired
                outgoing.assetAmounts[1], // amountBDesired
                outgoing.assetAmounts[0], // amountAMin
                outgoing.assetAmounts[1] // amountBMin
            ); //TODO: min amounts?
        } else if (bytes4(selector) == bytes4(keccak256("remove"))) {
            _uniswapV2RemoveLiquidity(
                address(this),
                outgoing.assets[0],
                outgoing.assetAmounts[0], // liquidity
                incoming.assets[0],
                incoming.assets[1],
                incoming.assetAmounts[0], // amountAMin
                incoming.assetAmounts[1] // amountBMin
            );
        }

        //require(incoming.assets.length == incoming.assetAmounts.length, "UV2A_LP: incoming assets and amounts length mismatch");
    }

    function _preCheck(bytes memory actionSpecificData)
        internal
        view
        returns (actionAssetsData memory outgoing, actionAssetsData memory incoming, bytes4 selector)
    {
        /*///////////////////////////////
                    DECODE
        ///////////////////////////////*/
        (outgoing, incoming, selector) =
            abi.decode(actionSpecificData, (actionAssetsData, actionAssetsData, bytes4));

        if (bytes4(selector) == bytes4(keccak256("add"))) {
            require(outgoing.assets.length >= 2, "UV2A_LP: Need atleast two base tokens");
            require(incoming.assets.length == 1, "UV2A_LP: Can only out one lp token");
        } else if (bytes4(selector) == bytes4(keccak256("remove"))) {
            require(outgoing.assets.length >= 1, "UV2A_LP: Can only out one lp token");
            require(incoming.assets.length == 2, "UV2A_LP: Need atleast two base tokens");
        }

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        for (uint256 i; i < incoming.assets.length;) {
            require(incoming.assets[i] != address(0), "UV2A_LP: incoming asset cannot be zero address");
            incoming.preActionBalances[i] = IERC20(incoming.assets[i]).balanceOf(address(this));
            unchecked {
                i++;
            }
        }

        //Check if incoming assets are Arcadia whitelisted assets
        require(
            IMainRegistry(MAIN_REGISTRY).batchIsWhiteListed(incoming.assets, incoming.assetIds),
            "UV2A_SWAP: Non-allowlisted incoming asset"
        );

        return (outgoing, incoming, selector);
    }

    function _postCheck(actionAssetsData memory incomingAssets)
        internal
        view
        returns (uint256[] memory incomingAssetAmounts)
    {
        /*///////////////////////////////
                    INCOMING
        ///////////////////////////////*/

        uint256 incomingLength = incomingAssets.assets.length;
        incomingAssetAmounts = new uint256[](incomingLength);
        for (uint256 i; i < incomingLength;) {
            incomingAssetAmounts[i] =
                IERC20(incomingAssets.assets[i]).balanceOf(address(this)) - incomingAssets.preActionBalances[i];

            // Check incoming assets are as expected
            require(
                incomingAssetAmounts[i] >= incomingAssets.assetAmounts[i],
                "UV2A_SWAP: Received incoming asset less than expected"
            );
            unchecked {
                i++;
            }
        }

        /*///////////////////////////////
                    OUTGOING
        ///////////////////////////////*/

        return incomingAssetAmounts;
    }
}
