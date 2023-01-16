/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import {ActionData} from "../actions/utils/ActionData.sol";

abstract contract ActionBase {
    address public immutable MAIN_REGISTRY;

    constructor(address mainreg) {
        MAIN_REGISTRY = mainreg;
    }

    function executeAction(bytes calldata actionData) external virtual returns (ActionData memory resultData) {}
}
