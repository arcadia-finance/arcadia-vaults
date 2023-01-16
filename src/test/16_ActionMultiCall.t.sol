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

contract VaultTestExtension is Vault {
    function setAllowed(address who, bool allow) public {
        allowed[who] = allow;
    }

    function setTrustedProtocol(address trustedProtocol_) public {
        trustedProtocol = trustedProtocol_;
    }

    function setIsTrustedProtocolSet(bool set) public {
        isTrustedProtocolSet = set;
    }
}

contract ActionMultiCallTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;
    LendingPool public pool;
    DebtToken public debt;
    Tranche public tranche;

    VaultTestExtension public proxy_;
    TrustedProtocolMock public trustedProtocol;

    function setUp() public {
        action = new ActionMultiCall();
        deal(address(eth), address(action), 1000 * 10 ** 20, false);

        vm.startPrank(creatorAddress);
        vault = new VaultTestExtension();
        factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeProof1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        proxyAddr = factory.createVault(12345678, 0);
        proxy_ = VaultTestExtension(proxyAddr);
        vm.stopPrank();

        depositERC20InVault(eth, 1000 * 10 ** 18, vaultOwner);

        vm.startPrank(creatorAddress);
        mainRegistry.setAllowedAction(address(action), true);

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));
        pool.setVaultVersion(1, true);
        debt = DebtToken(address(pool));
        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);

        trustedProtocol = new TrustedProtocolMock();
        vm.stopPrank();
    }

    function testSuccess_executeAction() public {
        actionAssetsData memory assetData = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetData.assets[0] = address(eth);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        bytes memory callData = abi.encode(assetData, assetData, to, data);

        action.executeAction(address(0), callData);
    }

    function testRevert_executeAction_lengthMismatch() public {
        actionAssetsData memory assetData = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
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
        action.executeAction(address(0), callData);
    }

    function testSuccess_vaultManagementAction_noDebt() public {
        multiActionMock = new MultiActionMock();

        bytes[] memory data = new bytes[](6);
        address[] memory to = new address[](6);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)", address(eth), address(link), 1000 * 10 ** 18, 1000 * 10 ** 18
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18);
        data[3] = abi.encodeWithSignature("assetSink(address,uint256)", address(link), 1000 * 10 ** 18);
        data[4] = abi.encodeWithSignature("assetSource(address,uint256)", address(link), 1000 * 10 ** 18);
        data[5] = abi.encodeWithSignature("approve(address,uint256)", address(proxy_), 1000 * 10 ** 18);

        deal(address(link), address(multiActionMock), 1000 * 10 ** 18, false);

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
            preActionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        actionAssetsData memory assetDataIn = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);
        emit log_named_bytes("callData", callData);

        vm.startPrank(vaultOwner);
        proxy_.vaultManagementAction(address(action), callData);
    }

    function testSuccess_vaultManagementAction_withDebt(uint128 debtAmount) public {
        multiActionMock = new MultiActionMock();

        proxy_.setAllowed(address(pool), true);
        vm.prank(address(pool));
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedProtocol(address(trustedProtocol));
        proxy_.setIsTrustedProtocolSet(true);
        trustedProtocol.setOpenPosition(debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + (uint256(debtAmount) * ethToLinkRatio) < type(uint256).max);

        //require(false, "1");
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        link.mint(address(multiActionMock), 1000 * 10 ** 18 + debtAmount * ethToLinkRatio);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        actionAssetsData memory assetDataOut = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        actionAssetsData memory assetDataIn = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(vaultOwner);
        proxy_.vaultManagementAction(address(action), callData);
        vm.stopPrank();
    }

    function testRevert_vaultManagementAction_InsufficientReturned(uint128 debtAmount) public {
        vm.assume(debtAmount > 0);

        multiActionMock = new MultiActionMock();

        proxy_.setAllowed(address(pool), true);
        vm.prank(address(pool));
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedProtocol(address(trustedProtocol));
        proxy_.setIsTrustedProtocolSet(true);
        trustedProtocol.setOpenPosition(debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + (uint256(debtAmount) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            0
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        actionAssetsData memory assetDataOut = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        actionAssetsData memory assetDataIn = actionAssetsData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            preActionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(vaultOwner);
        vm.expectRevert("VMA: coll. value too low");
        proxy_.vaultManagementAction(address(action), callData);
        vm.stopPrank();

        emit log_named_uint("link returned", (1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio) - 1);
        emit log_named_uint("ratio", ethToLinkRatio);
        emit log_named_uint("debt", debtAmount);
        emit log_named_uint("value", proxy_.getCollateralValue());
        emit log_named_uint("openpos", proxy_.getUsedMargin());
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
        token.approve(address(proxy_), amount);
        proxy_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function returnFive() public pure returns (uint256) {
        return 5;
    }
}
