/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import {MultiActionMock} from "../mockups/MultiActionMock.sol";

import {ActionMultiCall} from "../actions/MultiCall.sol";
import "../actions/utils/ActionData.sol";

import {TrustedProtocolMock} from "../mockups/TrustedProtocolMock.sol";
import {LendingPool, DebtToken, ERC20} from "../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../lib/arcadia-lending/src/Tranche.sol";

contract ActionMultiCallTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;


    ActionMultiCall public action;
    MultiActionMock public multiActionMock;
    LendingPool public pool;

    function setUp() public {
        action = new ActionMultiCall();
        deal(address(eth), address(action), 1000*10**20, false);

        vm.startPrank(vaultOwner);
        proxyAddr = factory.createVault(12345678, 0);
        proxy = Vault(proxyAddr);
        vm.stopPrank();
        
        depositERC20InVault(eth, 1000*10**18, vaultOwner);

        vm.prank(creatorAddress);
        mainRegistry.setAllowedAction(address(action), true);

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));
        pool.setVaultVersion(1, true);
        debt = DebtToken(address(pool));

    }

    function testDoCalls() public returns (actionAssetsData memory) {
        actionAssetsData memory assetData = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)});

        assetData.assets[0] = address(eth);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        bytes memory callData = abi.encode(assetData, assetData, to, data);

        return action.executeAction(address(0), callData);
    }

    function testAction() public {

        multiActionMock = new MultiActionMock();

        bytes[] memory data = new bytes[](6);
        address[] memory to = new address[](6);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), 1000*10**18);
        data[1] = abi.encodeWithSignature("swapAssets(address,address,uint256,uint256)", address(eth), address(link), 1000*10**18, 1000*10**18);
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), 1000*10**18);
        data[3] = abi.encodeWithSignature("assetSink(address,uint256)", address(link), 1000*10**18);
        data[4] = abi.encodeWithSignature("assetSource(address,uint256)", address(link), 1000*10**18);
        data[5] = abi.encodeWithSignature("approve(address,uint256)", address(proxy), 1000*10**18);

        deal(address(link), address(multiActionMock), 1000*10**18, false);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);
        to[3] = address(multiActionMock);
        to[4] = address(multiActionMock);
        to[5] = address(link);

        actionAssetsData memory assetDataOut = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)});

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000*10**18;
        

        actionAssetsData memory assetDataIn = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)});

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);
        emit log_named_bytes("callData", callData);

        vm.startPrank(vaultOwner);
        proxy.vaultManagementAction(address(action), callData);
    }



    function depositERC20InVault(ERC20Mock token, uint128 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        token.balanceOf(0x0000000000000000000000000000000000000006);

        vm.startPrank(sender);
        token.approve(address(proxy), amount);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function returnFive() public pure returns (uint256) {
        return 5;
    }

}