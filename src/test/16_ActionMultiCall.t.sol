/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import {ActionMultiCall} from "../actions/MultiCall.sol";
import "../actions/utils/ActionData.sol";

contract ActionMultiCallTest is DeployArcadiaVaults {

    ActionMultiCall public action;

    function setUp() public {
        action = new ActionMultiCall();
        deal(address(dai), address(action), 1000000000000000000, false);
    }

    function returnFive() public pure returns (uint256) {
        return 5;
    }

    function testDoCalls() public returns (actionAssetsData memory) {
        actionAssetsData memory assetData = actionAssetsData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            preActionBalances: new uint256[](0)});

        assetData.assets[0] = address(dai);

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        bytes memory callData = abi.encode(assetData, assetData, to, data);

        return action.executeAction(address(0), callData);
    }

}