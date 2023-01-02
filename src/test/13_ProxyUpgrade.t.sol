/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import "../mockups/VaultV2.sol";

import {LendingPool, DebtToken, ERC20} from "../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../lib/arcadia-lending/src/Tranche.sol";

contract VaultV2Test is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    VaultV2 private vaultV2;
    address private proxyAddr2;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    struct VaultInfo {
        uint16 collFactor;
        uint16 liqThres;
        address baseCurrency;
    }

    struct Checks {
        address erc20Stored;
        address erc721Stored;
        address erc1155Stored;
        uint256 erc721TokenIds;
        uint256 erc1155TokenIds;
        address registry;
        address trustedProtocol;
        uint256 life;
        address owner;
        VaultInfo vaultVar;
    }

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(
            address(factory),
            address(mainRegistry)
        );
        liquidator.setFactory(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));
        pool.setVaultVersion(1, true);
        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);
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
            0
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

        vaultV2 = new VaultV2();
        vm.stopPrank();
    }

    function testSuccess_confirmNewVaultInfo(uint256 salt) public {
        vm.assume(salt > 0);

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        assertEq(factory.getVaultVersionRoot(), Constants.upgradeRoot1To2);

        vm.startPrank(address(123456789));
        proxyAddr2 = factory.createVault(salt, 0);
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
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(vaultOwner);
        factory.upgradeVaultVersion(address(proxy), factory.latestVaultVersion(), proofs);
        vm.stopPrank();

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
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(vaultOwner);
        vm.expectRevert("FTR_UVV: Cannot upgrade to this version");
        factory.upgradeVaultVersion(address(proxy), 0, proofs);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vm.expectRevert("FTR_UVV: Cannot upgrade to this version");
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
        factory.setNewVaultInfo(address(mainRegistry), address(vaultV2), Constants.upgradeRoot1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(sender);
        vm.expectRevert("FTRY_UVV: You are not the owner");
        factory.upgradeVaultVersion(address(proxy), 2, proofs);
        vm.stopPrank();
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

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC20InVaultV2(ERC20Mock token, uint128 amount, address sender)
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

        vm.startPrank(sender);
        vaultV2.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC721InVault(ERC721Mock token, uint128[] memory tokenIds, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC1155InVault(ERC1155Mock token, uint256 tokenId, uint256 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetTypes = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;
        assetTypes[0] = 2;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function createCompareStruct() public view returns (Checks memory) {
        Checks memory checks;
        VaultInfo memory vaultVar;

        checks.erc20Stored = proxy.erc20Stored(0); //ToDo; improve for whole list
        checks.erc721Stored = proxy.erc721Stored(0);
        checks.erc1155Stored = proxy.erc1155Stored(0);
        checks.erc721TokenIds = proxy.erc721TokenIds(0);
        checks.erc1155TokenIds = proxy.erc1155TokenIds(0);
        checks.registry = proxy.registry();
        checks.trustedProtocol = proxy.trustedProtocol();
        checks.life = proxy.life();
        checks.owner = proxy.owner();
        (vaultVar.liqThres, vaultVar.baseCurrency) = proxy.vault();
        checks.vaultVar = vaultVar;

        return checks;
    }
}
