/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IActionBase.sol";

abstract contract ActionBase is IActionBase {

    function executeAction(bytes memory _actionData) external {}
    function _preExecuteActionData() internal {}
    function _execute() internal {}
    function _postExecuteCheck() internal {}

}
