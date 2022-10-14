/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";
import "../Factory.sol";
import "../Proxy.sol";
import "../Vault.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../Liquidator.sol";
import "../utils/Constants.sol";
import {LendingPool, DebtToken} from "../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../lib/arcadia-lending/src/Tranche.sol";
import {Asset} from "../../lib/arcadia-lending/src/mocks/Asset.sol";

interface IVaultExtra {
    function life() external view returns (uint256);

    function owner() external view returns (address);
}

contract factoryTest is Test {
    using stdStorage for StdStorage;

    Factory internal factoryContr;
    Vault internal vaultContr;
    Liquidator internal liquidatorContr;
    MainRegistry internal registryContr;
    MainRegistry internal registryContr2;

    Asset asset;
    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address internal unprivilegedAddress1 = address(5);
    address private liquidityProvider = address(7);

    uint256[] emptyList = new uint256[](0);
    uint16[] emptyListUint16 = new uint16[](0);

    event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 length);

    //this is a before
    constructor() {
        factoryContr = new Factory();
        vaultContr = new Vault();
        liquidatorContr = new Liquidator(
            address(factoryContr),
            0x0000000000000000000000000000000000000000
        );

        vm.startPrank(tokenCreatorAddress);
        asset = new Asset("Asset", "ASSET", uint8(Constants.assetDecimals));
        asset.mint(liquidityProvider, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        pool = new LendingPool(asset, creatorAddress, address(factoryContr));
        pool.updateInterestRate(5 * 10 ** 16); //5% with 18 decimals precision

        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);

        registryContr = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );

        factoryContr.setNewVaultInfo(address(registryContr), address(vaultContr), Constants.upgradeProof1To2);
        factoryContr.confirmNewVaultInfo();
        registryContr.setFactory(address(factoryContr));
    }

    //this is a before each
    function setUp() public {}

    function getBytecode(address vaultLogic) public pure returns (bytes memory) {
        bytes memory bytecode = type(Proxy).creationCode;

        return abi.encodePacked(bytecode, abi.encode(vaultLogic));
    }

    function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function testSuccess_allVaultsLength_VaultIdStartFromZero() public {
        assertEq(factoryContr.allVaultsLength(), 0);
    }

    function testSuccess_createVault_DeployVaultContractMappings(uint256 salt) public {
        uint256 amountBefore = factoryContr.allVaultsLength();

        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(actualDeployed, factoryContr.allVaults(factoryContr.allVaultsLength()));
        assertEq(factoryContr.vaultIndex(actualDeployed), (factoryContr.allVaultsLength()));
    }

    function testSuccess_createVault_DeployNewProxyWithLogic(uint256 salt) public {
        uint256 amountBefore = factoryContr.allVaultsLength();

        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(IVaultExtra(actualDeployed).life(), 0);

        assertEq(IVaultExtra(actualDeployed).owner(), address(this));
    }

    function testSuccess_createVault_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        uint256 amountBefore = factoryContr.allVaultsLength();
        vm.prank(sender);
        vm.assume(sender != address(0));
        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(IVaultExtra(actualDeployed).life(), 0);

        assertEq(IVaultExtra(actualDeployed).owner(), address(sender));

        emit log_address(address(1));
    }

    function testSuccess_safeTransferFrom(address sender) public {
        address receiver = unprivilegedAddress1;
        vm.assume(sender != address(0));

        vm.startPrank(sender);

        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

        //Transfer vault to another address
        factoryContr.safeTransferFrom(sender, receiver, factoryContr.vaultIndex(vault));

        //Make sure vault itself is owned by receiver
        assertEq(IVault(vault).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_NonOwner(address sender, address receiver) public {
        vm.assume(sender != receiver);
        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));

        vm.prank(sender);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

        //Transfer vault to another address by not owner
        uint256 index = factoryContr.vaultIndex(vault);
        vm.startPrank(receiver);
        vm.expectRevert("NOT_AUTHORIZED");
        factoryContr.safeTransferFrom(sender, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is still owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);
    }

    function testSuccess_transferFrom(address sender) public {
        address receiver = unprivilegedAddress1;
        vm.assume(sender != address(0));

        vm.startPrank(sender);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

        //Transfer vault to another address
        factoryContr.transferFrom(sender, receiver, factoryContr.vaultIndex(vault));

        //Make sure vault itself is owned by receiver
        assertEq(IVault(vault).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), receiver);
        vm.stopPrank();
    }

    function testRevert_transferFrom_NonOwner(address sender, address receiver) public {
        vm.assume(sender != receiver);
        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));

        vm.prank(sender);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

        //Transfer vault to another address
        uint256 index = factoryContr.vaultIndex(vault);
        vm.startPrank(receiver);
        vm.expectRevert("NOT_AUTHORIZED");
        factoryContr.transferFrom(sender, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by sender
        assertEq(IVault(vault).owner(), sender);

        //Make sure erc721 is still owned by sender
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);
    }

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));
        Factory factoryContr_m = new Factory();

        assertEq(address(this), factoryContr_m.owner());

        factoryContr_m.transferOwnership(to);
        assertEq(to, factoryContr_m.owner());
    }

    function testRevert_transferOwnership_NonOwner(address from) public {
        Factory factoryContr_m = new Factory();
        vm.assume(from != address(this) && from != address(factoryContr_m));

        address to = address(12345);

        assertEq(address(this), factoryContr_m.owner());

        vm.startPrank(from);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr_m.transferOwnership(to);
        assertEq(address(this), factoryContr_m.owner());
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    //Test setNewVaultInfo
    function testRevert_setNewVaultInfo_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != address(this));
        vm.assume(unprivilegedAddress != address(factoryContr));
        vm.assume(unprivilegedAddress != address(0));
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.setNewVaultInfo(address(registryContr), address(vaultContr), Constants.upgradeProof1To2);
        vm.stopPrank();
    }

    function testSuccess_setNewVaultInfo_OwnerSetsVaultInfoForFirstTime(address registry, address logic) public {
        vm.assume(logic != address(0));

        factoryContr = new Factory();
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertTrue(!factoryContr.newVaultInfoSet());

        factoryContr.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoSecondTimeWithIdenticalMainRegistry(address logic)
        public
    {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultInfoWithDifferentLendingPoolContractInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(randomAssetAddress != 0x0000000000000000000000000000000000000000);

        registryContr2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: randomAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI:No match baseCurrencies MR");
        factoryContr.setNewVaultInfo(address(registryContr2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));

        vm.assume(newAssetAddress != address(0));

        registryContr.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );

        registryContr2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI:No match baseCurrencies MR");
        factoryContr.setNewVaultInfo(address(registryContr2), logic, Constants.upgradeProof1To2);
        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testSuccess_setFactory_OwnerSetsNewVaultWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));

        registryContr.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );

        registryContr2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        registryContr2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        factoryContr.setNewVaultInfo(address(registryContr2), logic, Constants.upgradeProof1To2);
        factoryContr.confirmNewVaultInfo();
        registryContr2.setFactory(address(factoryContr));

        assertEq(2, factoryContr.latestVaultVersion());
    }

    function testSuccess_setFactory_OwnerSetsNewVaultWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));

        registryContr2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        registryContr2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );
        factoryContr.setNewVaultInfo(address(registryContr2), logic, Constants.upgradeProof1To2);
        factoryContr.confirmNewVaultInfo();
        registryContr2.setFactory(address(factoryContr));

        assertEq(2, factoryContr.latestVaultVersion());
    }

    function testRevert_confirmNewVaultInfo_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != address(0) && unprivilegedAddress != address(this));
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.confirmNewVaultInfo();
        vm.stopPrank();
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoForFirstTime(address registry, address logic)
        public
    {
        vm.assume(logic != address(0));

        factoryContr = new Factory();
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertEq(0, factoryContr.latestVaultVersion());

        factoryContr.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());

        factoryContr.confirmNewVaultInfo();
        assertTrue(factoryContr.getVaultVersionRoot() == Constants.upgradeProof1To2);
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        factoryContr.confirmNewVaultInfo();
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(2, factoryContr.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoWithoutNewVaultInfoSet() public {
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        factoryContr.confirmNewVaultInfo();
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testRevert_createVault_CreateNonExistingVaultVersion(uint256 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown vault version");
        factoryContr.createVault(uint256(keccak256(abi.encodePacked(vaultVersion, block.timestamp))), vaultVersion);
    }

    function testSuccess_blockVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);
        factoryContr.blockVaultVersion(vaultVersion);

        assertTrue(factoryContr.vaultVersionBlocked(vaultVersion));
    }

    function testRevert_blockVaultVersion_BlockNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion || vaultVersion == 0);

        vm.expectRevert("FTRY_BVV: Invalid version");
        factoryContr.blockVaultVersion(vaultVersion);
    }

    function testRevert_blockVaultVersion_ByNonOwner(uint16 vaultVersion, address sender) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.assume(sender != address(this));
        vm.startPrank(sender);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testRevert_createVault_FromBlockedVersion(
        uint16 vaultVersion,
        uint16 versionsToMake,
        uint16[] calldata versionsToBlock
    ) public {
        vm.assume(versionsToBlock.length < 10 && versionsToBlock.length > 0);
        vm.assume(uint256(versionsToMake) + 1 < type(uint16).max);
        vm.assume(vaultVersion <= versionsToMake + 1);
        for (uint256 i; i < versionsToMake; ++i) {
            factoryContr.setNewVaultInfo(address(registryContr), address(vaultContr), Constants.upgradeProof1To2);
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factoryContr.latestVaultVersion()) {
                continue;
            }
            factoryContr.blockVaultVersion(versionsToBlock[y]);
        }

        for (uint256 z; z < versionsToBlock.length; ++z) {
            if (versionsToBlock[z] == 0 || versionsToBlock[z] > factoryContr.latestVaultVersion()) {
                continue;
            }
            vm.expectRevert("FTRY_CV: This vault version cannot be created");
            factoryContr.createVault(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))), versionsToBlock[z]
            );
        }
    }
}
