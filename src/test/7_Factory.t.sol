/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";
import "../Factory.sol";
import "../Vault.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../Liquidator.sol";
import "../utils/Constants.sol";

contract factoryTest is Test {
    using stdStorage for StdStorage;

    Factory internal factory;
    Vault internal vault;
    address proxy;
    Liquidator internal liquidator;
    MainRegistry internal registry;
    MainRegistry internal registry2;

    address private creatorAddress = address(1);

    uint16[] emptyListUint16 = new uint16[](0);

    //events
    event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 length);

    //this is a before
    constructor() {
        vm.startPrank(creatorAddress);
        factory = new Factory();
        vault = new Vault();
        liquidator = new Liquidator(
            address(factory),
            0x0000000000000000000000000000000000000000
        );

        registry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );

        factory.setNewVaultInfo(address(registry), address(vault), Constants.upgradeProof1To2);
        factory.confirmNewVaultInfo();
        registry.setFactory(address(factory));
        vm.stopPrank();
    }

    //this is a before each
    function setUp() public {}

    /*///////////////////////////////////////////////////////////////
                          CONTRACT OWNERSHIP
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_transferOwnership(address owner, address to) public {
        vm.assume(to != address(0));

        vm.prank(owner);
        Factory factoryContr_m = new Factory();
        assertEq(owner, factoryContr_m.owner());

        vm.prank(owner);
        factoryContr_m.transferOwnership(to);
        assertEq(to, factoryContr_m.owner());
    }

    function testRevert_transferOwnership_NonOwner(address owner, address to, address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != owner);

        vm.prank(owner);
        Factory factoryContr_m = new Factory();
        assertEq(owner, factoryContr_m.owner());

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr_m.transferOwnership(to);
        vm.stopPrank();

        assertEq(owner, factoryContr_m.owner());
    }

    /*///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_createVault_DeployVaultContractMappings(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        address actualDeployed = factory.createVault(salt, 0);
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
    }

    function testSuccess_createVault_DeployNewProxyWithLogic(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        address actualDeployed = factory.createVault(salt, 0);
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(Vault(actualDeployed).life(), 0);

        assertEq(Vault(actualDeployed).owner(), address(this));
    }

    function testSuccess_createVault_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        uint256 amountBefore = factory.allVaultsLength();
        vm.prank(sender);
        vm.assume(sender != address(0));
        address actualDeployed = factory.createVault(salt, 0);
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(Vault(actualDeployed).life(), 0);

        assertEq(Vault(actualDeployed).owner(), address(sender));
    }

    function testRevert_createVault_CreateNonExistingVaultVersion(uint256 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown vault version");
        factory.createVault(uint256(keccak256(abi.encodePacked(vaultVersion, block.timestamp))), vaultVersion);
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
            vm.prank(creatorAddress);
            factory.setNewVaultInfo(address(registry), address(vault), Constants.upgradeProof1To2);
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factory.latestVaultVersion()) {
                continue;
            }
            vm.prank(creatorAddress);
            factory.blockVaultVersion(versionsToBlock[y]);
        }

        for (uint256 z; z < versionsToBlock.length; ++z) {
            if (versionsToBlock[z] == 0 || versionsToBlock[z] > factory.latestVaultVersion()) {
                continue;
            }
            vm.expectRevert("FTRY_CV: This vault version cannot be created");
            factory.createVault(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))), versionsToBlock[z]
            );
        }
    }

    function testSuccess_isVault_positive() public {
        proxy = factory.createVault(0, 0);

        bool expectedReturn = factory.isVault(address(proxy));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }

    function testSuccess_isVault_negative(address random) public {
        bool expectedReturn = factory.isVault(random);
        bool actualReturn = false;

        assertEq(expectedReturn, actualReturn);
    }

    //For tests upgradeVaultVersion, see 13_ProxyUpgrade.t.sol

    function testSuccess_safeTransferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxy = factory.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(proxy).owner(), factory.ownerOf(1));

        //Make sure proxy itself is owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);

        //Transfer proxy to another address
        factory.safeTransferFrom(owner, receiver, factory.vaultIndex(proxy));

        //Make sure proxy itself is owned by receiver
        assertEq(IVault(proxy).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress)
        public
    {
        vm.assume(owner != unprivilegedAddress);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));
        vm.assume(unprivilegedAddress != address(0));

        vm.prank(owner);
        proxy = factory.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(proxy).owner(), factory.ownerOf(1));

        //Make sure proxy itself is owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);

        //Transfer proxy to another address by not owner
        uint256 index = factory.vaultIndex(proxy);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure proxy itself is still owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);
    }

    function testSuccess_transferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxy = factory.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(proxy).owner(), factory.ownerOf(1));

        //Make sure proxy itself is owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);

        //Transfer proxy to another address
        factory.transferFrom(owner, receiver, factory.vaultIndex(proxy));

        //Make sure proxy itself is owned by receiver
        assertEq(IVault(proxy).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), receiver);
        vm.stopPrank();
    }

    function testRevert_transferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress) public {
        vm.assume(owner != unprivilegedAddress);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));

        vm.prank(owner);
        proxy = factory.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(proxy).owner(), factory.ownerOf(1));

        //Make sure proxy itself is owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);

        //Transfer proxy to another address
        uint256 index = factory.vaultIndex(proxy);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.transferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure proxy itself is still owned by owner
        assertEq(IVault(proxy).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxy)), owner);
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_setNewVaultInfo_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setNewVaultInfo(address(registry), address(proxy), Constants.upgradeProof1To2);
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_VersionRootIsZero(address registry, address logic) public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: version root is zero");
        factory.setNewVaultInfo(registry, logic, bytes32(0));
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_LogicAddressIsZero(address registry, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: logic address is zero");
        factory.setNewVaultInfo(registry, address(0), versionRoot);
        vm.stopPrank();
    }

    function testSuccess_setNewVaultInfo_OwnerSetsVaultInfoForFirstTime(address registry, address logic) public {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new Factory();
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertTrue(!factory.newVaultInfoSet());

        vm.prank(creatorAddress);
        factory.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertTrue(factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(registry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoSecondTimeWithIdenticalMainRegistry(address logic)
        public
    {
        vm.assume(logic != address(0));

        assertTrue(!factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(registry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(registry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultInfoWithDifferentBaseCurrencyInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(randomAssetAddress != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        registry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: randomAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI:No match baseCurrencies MR");
        factory.setNewVaultInfo(address(registry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(false, factory.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        registry.addBaseCurrency(
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

        registry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI:No match baseCurrencies MR");
        factory.setNewVaultInfo(address(registry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(false, factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        registry.addBaseCurrency(
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

        registry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        registry2.addBaseCurrency(
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
        factory.setNewVaultInfo(address(registry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(true, factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        registry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        registry2.addBaseCurrency(
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
        factory.setNewVaultInfo(address(registry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(true, factory.newVaultInfoSet());
    }

    function testRevert_confirmNewVaultInfo_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.confirmNewVaultInfo();
        vm.stopPrank();
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoForFirstTime(address registry, address logic)
        public
    {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new Factory();
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertEq(0, factory.latestVaultVersion());

        vm.prank(creatorAddress);
        factory.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());

        vm.prank(creatorAddress);
        factory.confirmNewVaultInfo();
        assertTrue(factory.getVaultVersionRoot() == Constants.upgradeProof1To2);
        assertTrue(!factory.newVaultInfoSet());
        assertEq(1, factory.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factory.newVaultInfoSet());
        assertEq(1, factory.latestVaultVersion());

        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(registry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
        assertEq(1, factory.latestVaultVersion());

        vm.prank(creatorAddress);
        factory.confirmNewVaultInfo();
        assertTrue(!factory.newVaultInfoSet());
        assertEq(2, factory.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoWithoutNewVaultInfoSet() public {
        assertTrue(!factory.newVaultInfoSet());
        assertEq(1, factory.latestVaultVersion());

        vm.prank(creatorAddress);
        factory.confirmNewVaultInfo();
        assertTrue(!factory.newVaultInfoSet());
        assertEq(1, factory.latestVaultVersion());
    }

    function testSuccess_blockVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.prank(creatorAddress);
        factory.blockVaultVersion(vaultVersion);

        assertTrue(factory.vaultVersionBlocked(vaultVersion));
    }

    function testRevert_blockVaultVersion_BlockNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion || vaultVersion == 0);

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_BVV: Invalid version");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testRevert_blockVaultVersion_ByNonOwner(uint16 vaultVersion, address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT LIQUIDATION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_allVaultsLength_VaultIdStartFromZero() public {
        assertEq(factory.allVaultsLength(), 0);
    }

    function testSuccess_getCurrentRegistry() public {
        address expectedRegistry = factory.getCurrentRegistry();
        address actualRegistry = address(registry);

        assertEq(expectedRegistry, actualRegistry);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_setBaseURI(string calldata uri) public {
        vm.prank(creatorAddress);
        factory.setBaseURI(uri);

        string memory expectedUri = factory.baseURI();

        assertEq(expectedUri, uri);
    }

    function testRevert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress) public {
        vm.assume(address(unprivilegedAddress) != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setBaseURI(uri);
        vm.stopPrank();
    }
}
