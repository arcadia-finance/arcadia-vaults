/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IActionBase.sol";
import "./utils/ActionAssetData.sol";

abstract contract ActionBase is IActionBase {
    address public immutable MAIN_REGISTRY;

    constructor(address _mainreg) {
        MAIN_REGISTRY = _mainreg;
    }

    function executeAction(address _vaultAddress, bytes calldata _actionData)
        external
        virtual
        returns (actionAssetsData memory _resultData)
    {}
}
