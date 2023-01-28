/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.13;

import "../actions/utils/ActionData.sol";
import {ActionBase} from "./ActionBase.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC1155.sol";

/**
 * @title Generic multicall action
 * @author Arcadia Finance
 * @notice Call any external contract with arbitrary data. Return the balances of assets that need to be deposited within a vault.
 * @dev Only calls are used, no delegatecalls
 * This address will approve random addresses. Do not store any funds on this address!
 */

contract ActionMultiCall is ActionBase {
    constructor(address mainRegistry_) ActionBase(mainRegistry_) {}

    /**
     * @notice Calls a series of addresses with arbitrrary calldata
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return incoming An actionAssetData struct with the balances of this ActionMultiCall address.
     * @dev input address is not used in this generic action.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        (, ActionData memory incoming, address[] memory to, bytes[] memory data) =
            abi.decode(actionData, (ActionData, ActionData, address[], bytes[]));

        uint256 callLength = to.length;

        require(data.length == callLength, "EA: Length mismatch");

        for (uint256 i; i < callLength;) {
            (bool success, bytes memory result) = to[i].call(data[i]);
            require(success, string(result));

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < incoming.assets.length;) {
            if (incoming.assetTypes[i] == 0) {
                incoming.assetAmounts[i] = IERC20(incoming.assets[i]).balanceOf(address(this));
            } else if (incoming.assetTypes[i] == 2) {
                incoming.assetAmounts[i] = IERC1155(incoming.assets[i]).balanceOf(address(this), incoming.assetIds[i]);
            }
            unchecked {
                ++i;
            }
        }

        return incoming;
    }
}
