/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { ActionData } from "../actions/utils/ActionData.sol";

abstract contract ActionBase {
    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     */
    function executeAction(bytes calldata actionData) external virtual returns (ActionData memory resultData) { }
}
