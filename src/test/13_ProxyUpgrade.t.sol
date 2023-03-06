/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import { VaultV2 } from "../mockups/VaultV2.sol";

import { LendingPool, DebtToken, ERC20 } from "../../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../../lib/arcadia-lending/src/Tranche.sol";

contract VaultV2Test is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    VaultV2 private vaultV2;
    address private proxyAddr2;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    struct Checks {
        bool isTrustedCreditorSet;
        uint16 vaultVersion;
        address baseCurrency;
        address owner;
        address liquidator;
        address registry;
        address trustedCreditor;
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    // EVENTS
    event VaultUpgraded(address indexed vaultAddress, uint16 oldVersion, uint16 indexed newVersion);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory), address(liquidator));
        pool.setVaultVersion(1, true);
        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50, 0);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                    )
                )
            ),
            0,
            address(0)
        );
        proxy = Vault(proxyAddr);
        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(proxy), type(uint256).max);

        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        dai.approve(address(liquidator), type(uint256).max);

        vaultV2 = new VaultV2(address(mainRegistry), 2);
        vm.stopPrank();
    }

    function testSuccess_getVaultVersionRoot(uint256 salt) public {
        vm.assume(salt > 0);

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        assertEq(factory.getVaultVersionRoot(), Constants.upgradeRoot1To2);

        vm.startPrank(address(123_456_789));
        proxyAddr2 = factory.createVault(salt, 0, address(0));
        vaultV2 = VaultV2(proxyAddr2);
        assertEq(vaultV2.returnFive(), 5);
        vm.stopPrank();
    }

    function testSuccess_upgradeVaultVersion_StorageVariablesAfterUpgradeAreIdentical(uint128 amount) public {
        vm.assume(amount > 0);
        depositERC20InVault(eth, amount, vaultOwner);
        uint128[] memory tokenIds = new uint128[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        depositERC721InVault(bayc, tokenIds, vaultOwner);
        depositERC1155InVault(interleave, 1, 1000, vaultOwner);

        Checks memory checkBefore = createCompareStruct();

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(creatorAddress);
        pool.setVaultVersion(factory.latestVaultVersion(), true);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, true, true);
        emit VaultUpgraded(address(proxy), 1, 2);
        factory.upgradeVaultVersion(address(proxy), factory.latestVaultVersion(), proofs);
        vm.stopPrank();

        assertEq(VaultV2(proxyAddr).check(), 5);

        Checks memory checkAfter = createCompareStruct();

        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));
        emit log_named_bytes32("before", keccak256(abi.encode(checkBefore)));
        emit log_named_bytes32("after", keccak256(abi.encode(checkAfter)));
        assertEq(factory.latestVaultVersion(), proxy.vaultVersion());
    }

    function testRevert_upgradeVaultVersion_IncompatibleVersionWithCurrentVault(uint128 amount) public {
        depositERC20InVault(eth, amount, vaultOwner);
        uint128[] memory tokenIds = new uint128[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        depositERC721InVault(bayc, tokenIds, vaultOwner);
        depositERC1155InVault(interleave, 1, 1000, vaultOwner);

        Checks memory checkBefore = createCompareStruct();

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(vaultOwner);
        vm.expectRevert("FTR_UVV: Version not allowed");
        factory.upgradeVaultVersion(address(proxy), 0, proofs);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vm.expectRevert("FTR_UVV: Version not allowed");
        factory.upgradeVaultVersion(address(proxy), 3, proofs);
        vm.stopPrank();

        Checks memory checkAfter = createCompareStruct();

        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));
        emit log_named_bytes32("before", keccak256(abi.encode(checkBefore)));
        emit log_named_bytes32("after", keccak256(abi.encode(checkAfter)));
    }

    function testRevert_upgradeVaultVersion_UpgradeVaultByNonOwner(address sender) public {
        vm.assume(sender != address(6));

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(sender);
        vm.expectRevert("FTRY_UVV: Only Owner");
        factory.upgradeVaultVersion(address(proxy), 2, proofs);
        vm.stopPrank();
    }

    function depositERC20InVault(ERC20Mock token, uint128 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC20InVaultV2(ERC20Mock token, uint128 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        vaultV2.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC721InVault(ERC721Mock token, uint128[] memory tokenIds, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.getOwnerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC1155InVault(ERC1155Mock token, uint256 tokenId, uint256 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function createCompareStruct() public view returns (Checks memory) {
        Checks memory checks;

        checks.isTrustedCreditorSet = proxy.isTrustedCreditorSet();
        checks.baseCurrency = proxy.baseCurrency();
        checks.owner = proxy.owner();
        checks.liquidator = proxy.liquidator();
        checks.registry = proxy.registry();
        checks.trustedCreditor = proxy.trustedCreditor();
        (checks.assetAddresses, checks.assetIds, checks.assetAmounts) = proxy.generateAssetData();

        return checks;
    }
}
