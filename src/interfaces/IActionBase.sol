/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "../AssetManagement/utils/ActionAssetData.sol";

interface IActionBase {
    function executeAction(bytes memory _actionData) external returns (actionAssetsData memory _result);
}
