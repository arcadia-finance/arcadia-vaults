/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../actions/utils/ActionData.sol";

interface IActionBase {
    /**
     * @notice Calls a series of addresses with arbitrrary calldata.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     */
    function executeAction(bytes calldata actionData) external returns (ActionData memory);
}
