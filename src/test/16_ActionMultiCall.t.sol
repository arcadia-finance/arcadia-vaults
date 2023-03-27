/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import { MultiActionMock } from "../mockups/MultiActionMock.sol";

import { ActionMultiCall } from "../actions/MultiCall.sol";
import { ActionMultiCallV2 } from "../actions/MultiCallV2.sol";
import "../actions/utils/ActionData.sol";

import { ERC20Mock } from "../mockups/ERC20SolmateMock.sol";

contract ActionMultiCallTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    uint256 public numberStored;

    function setUp() public {
        action = new ActionMultiCall();
    }

    function testSuccess_executeAction_storeNumber(uint256 number) public {
        ActionData memory assetData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetData.assets[0] = address(eth);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("setNumberStored(uint256)", number);

        bytes memory callData = abi.encode(assetData, assetData, to, data);

        action.executeAction(callData);

        assertEq(numberStored, number);
    }

    function testRevert_executeAction_lengthMismatch() public {
        ActionData memory assetData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetData.assets[0] = address(eth);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](2);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        to[1] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        bytes memory callData = abi.encode(assetData, assetData, to, data);

        vm.expectRevert("EA: Length mismatch");
        action.executeAction(callData);
    }

    function testRevert_checkAmountOut(uint256 amount) public {
        vm.assume(amount > 0);

        ActionMultiCallV2 actionV2 = new ActionMultiCallV2();
        ERC20Mock erc20 = new ERC20Mock("ERC20", "ERC20", 18);

        vm.expectRevert("CS: amountOut too low");
        actionV2.checkAmountOut(address(erc20), amount);
    }

    function testSuccess_checkAmountOut(uint256 amount, uint256 balance) public {
        vm.assume(balance >= amount);
        ActionMultiCallV2 actionV2 = new ActionMultiCallV2();
        ERC20Mock erc20 = new ERC20Mock("ERC20", "ERC20", 18);
        erc20.mint(address(actionV2), balance);

        actionV2.checkAmountOut(address(erc20), amount);
    }

    function setNumberStored(uint256 number) public {
        numberStored = number;
    }
}
