// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >0.8.13;

import "../actions/utils/ActionData.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC1155.sol";

contract ActionMultiCall {

    event log(uint256 value);
    function executeAction(address, bytes calldata actionData) external returns (actionAssetsData memory) {
        emit log(1);
        (, actionAssetsData memory incoming, address[] memory to, bytes[] memory data) =
            abi.decode(actionData, (actionAssetsData, actionAssetsData, address[], bytes[]));
        emit log(2);

        uint256 callLength = to.length;

        require(to.length == callLength, "ActionMultiCall: to and data arrays must be the same length");

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
