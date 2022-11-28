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

    Factory internal factoryContr;
    Vault internal vaultContr;
    Liquidator internal liquidatorContr;
    MainRegistry internal registryContr;
    MainRegistry internal registryContr2;

    address private creatorAddress = address(1);

    uint16[] emptyListUint16 = new uint16[](0);

    event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 length);

    //this is a before
    constructor() {
        vm.startPrank(creatorAddress);
        factoryContr = new Factory();
        vaultContr = new Vault();
        liquidatorContr = new Liquidator(
            address(factoryContr),
            0x0000000000000000000000000000000000000000
        );

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
        uint256 amountBefore = factoryContr.allVaultsLength();

        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(actualDeployed, factoryContr.allVaults(factoryContr.allVaultsLength() - 1));
        assertEq(factoryContr.vaultIndex(actualDeployed), (factoryContr.allVaultsLength()));
    }

    function testSuccess_createVault_DeployNewProxyWithLogic(uint256 salt) public {
        uint256 amountBefore = factoryContr.allVaultsLength();

        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(Vault(actualDeployed).life(), 0);

        assertEq(Vault(actualDeployed).owner(), address(this));
    }

    function testSuccess_createVault_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        uint256 amountBefore = factoryContr.allVaultsLength();
        vm.prank(sender);
        vm.assume(sender != address(0));
        address actualDeployed = factoryContr.createVault(salt, 0);
        assertEq(amountBefore + 1, factoryContr.allVaultsLength());
        assertEq(Vault(actualDeployed).life(), 0);

        assertEq(Vault(actualDeployed).owner(), address(sender));
    }

    function testRevert_createVault_CreateNonExistingVaultVersion(uint256 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown vault version");
        factoryContr.createVault(uint256(keccak256(abi.encodePacked(vaultVersion, block.timestamp))), vaultVersion);
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
            factoryContr.setNewVaultInfo(address(registryContr), address(vaultContr), Constants.upgradeProof1To2);
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factoryContr.latestVaultVersion()) {
                continue;
            }
            vm.prank(creatorAddress);
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

    function testSuccess_isVault() public {
        address vault = factoryContr.createVault(0, 0);

        bool expectedReturn = factoryContr.isVault(address(vault));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }

    //For tests upgradeVaultVersion, see 13_ProxyUpgrade.t.sol

    function testSuccess_safeTransferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);

        //Transfer vault to another address
        factoryContr.safeTransferFrom(owner, receiver, factoryContr.vaultIndex(vault));

        //Make sure vault itself is owned by receiver
        assertEq(IVault(vault).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress)
        public
    {
        vm.assume(owner != unprivilegedAddress);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));

        vm.prank(owner);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);

        //Transfer vault to another address by not owner
        uint256 index = factoryContr.vaultIndex(vault);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("NOT_AUTHORIZED");
        factoryContr.safeTransferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);
    }

    function testSuccess_transferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);

        //Transfer vault to another address
        factoryContr.transferFrom(owner, receiver, factoryContr.vaultIndex(vault));

        //Make sure vault itself is owned by receiver
        assertEq(IVault(vault).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), receiver);
        vm.stopPrank();
    }

    function testRevert_transferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress) public {
        vm.assume(owner != unprivilegedAddress);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));

        vm.prank(owner);
        address vault = factoryContr.createVault(0, 0);

        //Make sure index in erc721 == vaultIndex
        assertEq(IVault(vault).owner(), factoryContr.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);

        //Transfer vault to another address
        uint256 index = factoryContr.vaultIndex(vault);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("NOT_AUTHORIZED");
        factoryContr.transferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(IVault(vault).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), owner);
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

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

        vm.prank(creatorAddress);
        factoryContr = new Factory();
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertTrue(!factoryContr.newVaultInfoSet());

        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoSecondTimeWithIdenticalMainRegistry(address logic)
        public
    {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultInfoWithDifferentBaseCurrencyInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(randomAssetAddress != 0x0000000000000000000000000000000000000000);
        assertEq(false, factoryContr.newVaultInfoSet());

        vm.startPrank(creatorAddress);
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

        assertEq(false, factoryContr.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));
        assertEq(false, factoryContr.newVaultInfoSet());

        vm.startPrank(creatorAddress);
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
        vm.stopPrank();

        assertEq(false, factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        assertEq(false, factoryContr.newVaultInfoSet());

        vm.startPrank(creatorAddress);
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
        vm.stopPrank();

        assertEq(true, factoryContr.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        assertEq(false, factoryContr.newVaultInfoSet());

        vm.startPrank(creatorAddress);
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
        vm.stopPrank();

        assertEq(true, factoryContr.newVaultInfoSet());
    }

    function testRevert_confirmNewVaultInfo_NonOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.confirmNewVaultInfo();
        vm.stopPrank();
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoForFirstTime(address registry, address logic)
        public
    {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factoryContr = new Factory();
        assertTrue(factoryContr.getVaultVersionRoot() == bytes32(0));
        assertEq(0, factoryContr.latestVaultVersion());

        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(registry, logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());

        vm.prank(creatorAddress);
        factoryContr.confirmNewVaultInfo();
        assertTrue(factoryContr.getVaultVersionRoot() == Constants.upgradeProof1To2);
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        vm.prank(creatorAddress);
        factoryContr.setNewVaultInfo(address(registryContr), logic, Constants.upgradeProof1To2);
        assertTrue(factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        vm.prank(creatorAddress);
        factoryContr.confirmNewVaultInfo();
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(2, factoryContr.latestVaultVersion());
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoWithoutNewVaultInfoSet() public {
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());

        vm.prank(creatorAddress);
        factoryContr.confirmNewVaultInfo();
        assertTrue(!factoryContr.newVaultInfoSet());
        assertEq(1, factoryContr.latestVaultVersion());
    }

    function testSuccess_blockVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.prank(creatorAddress);
        factoryContr.blockVaultVersion(vaultVersion);

        assertTrue(factoryContr.vaultVersionBlocked(vaultVersion));
    }

    function testRevert_blockVaultVersion_BlockNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion || vaultVersion == 0);

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_BVV: Invalid version");
        factoryContr.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testRevert_blockVaultVersion_ByNonOwner(uint16 vaultVersion, address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        uint256 currentVersion = factoryContr.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT LIQUIDATION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_allVaultsLength_VaultIdStartFromZero() public {
        assertEq(factoryContr.allVaultsLength(), 0);
    }

    function testSuccess_getCurrentRegistry() public {
        address expectedRegistry = factoryContr.getCurrentRegistry();
        address actualRegistry = address(registryContr);

        assertEq(expectedRegistry, actualRegistry);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_setBaseURI(string calldata uri) public {
        vm.prank(creatorAddress);
        factoryContr.setBaseURI(uri);

        string memory expectedUri = factoryContr.baseURI();

        assertEq(expectedUri, uri);
    }

    function testRevert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress) public {
        vm.assume(address(unprivilegedAddress) != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr.setBaseURI(uri);
        vm.stopPrank();
    }
}
