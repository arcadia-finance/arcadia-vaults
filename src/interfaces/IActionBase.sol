/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../actions/utils/ActionData.sol";

interface IActionBase {
    function executeAction(address vaultAddress, bytes calldata actionData)
        external
        returns (actionAssetsData memory result);
}
