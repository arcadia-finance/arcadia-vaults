/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract FactoryTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    MainRegistry internal mainRegistry2;

    //events
    event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 length);

    //this is a before
    constructor() DeployArcadiaVaults() {}

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        factory = new Factory();
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );

        factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeProof1To2);
        factory.confirmNewVaultInfo();
        mainRegistry.setFactory(address(factory));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          CONTRACT OWNERSHIP
    /////////////////////////////////////////////////////////////// */

    function testSuccess_transferOwnership(address owner, address to) public {
        vm.assume(to != address(0));

        vm.prank(owner);
        Factory factoryContr_m = new Factory();
        assertEq(owner, factoryContr_m.owner());

        vm.prank(owner);
        factoryContr_m.transferOwnership(to);
        assertEq(to, factoryContr_m.owner());
    }

    function testRevert_transferOwnership_NonOwner(address owner, address to, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != owner);

        vm.prank(owner);
        Factory factoryContr_m = new Factory();
        assertEq(owner, factoryContr_m.owner());

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        factoryContr_m.transferOwnership(to);
        vm.stopPrank();

        assertEq(owner, factoryContr_m.owner());
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testSuccess_createVault_DeployVaultContractMappings(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        address actualDeployed = factory.createVault(salt, 0, address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
    }

    function testSuccess_createVault_DeployNewProxyWithLogic(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        address actualDeployed = factory.createVault(salt, 0, address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(Vault(actualDeployed).owner(), address(this));
    }

    function testSuccess_createVault_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        uint256 amountBefore = factory.allVaultsLength();
        vm.prank(sender);
        vm.assume(sender != address(0));
        address actualDeployed = factory.createVault(salt, 0, address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(Vault(actualDeployed).owner(), address(sender));
    }

    function testRevert_createVault_CreateNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown vault version");
        factory.createVault(
            uint256(keccak256(abi.encodePacked(vaultVersion, block.timestamp))), vaultVersion, address(0)
        );
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
            factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeProof1To2);
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
            vm.expectRevert("FTRY_CV: Vault version blocked");
            factory.createVault(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))),
                versionsToBlock[z],
                address(0)
            );
        }
    }

    function testRevert_createVault_Paused(uint256 salt, address sender, address guardian) public {
        vm.assume(sender != address(0));
        vm.assume(guardian != address(0));
        vm.assume(sender != guardian);

        // Given: variables and initialization
        vm.prank(creatorAddress);
        factory.changeGuardian(guardian);
        vm.warp(35 days);

        // When: guardian pauses the contract
        vm.prank(guardian);
        factory.pause();

        // Then: Reverted
        vm.prank(sender);
        vm.expectRevert("Guardian: create paused");
        factory.createVault(salt, 0, address(0));
    }

    function testSuccess_isVault_positive() public {
        proxyAddr = factory.createVault(0, 0, address(0));

        bool expectedReturn = factory.isVault(address(proxyAddr));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }

    function testSuccess_isVault_negative(address random) public {
        bool expectedReturn = factory.isVault(random);
        bool actualReturn = false;

        assertEq(expectedReturn, actualReturn);
    }

    function testSuccess_ownerOfVault_NonVault(address nonVault) public {
        assertEq(factory.ownerOfVault(nonVault), address(0));
    }

    function testSuccess_ownerOfVault_ExistingVault(address owner) public {
        vm.assume(owner != address(0));
        vm.prank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        assertEq(factory.ownerOfVault(proxyAddr), owner);
    }

    //For tests upgradeVaultVersion, see 13_ProxyUpgrade.t.sol

    function testSuccess_safeTransferFrom_OnVaultAddress(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address
        factory.safeTransferFrom(owner, receiver, proxyAddr);

        //Make sure vault itself is owned by receiver
        assertEq(Vault(proxyAddr).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_OnVaultAddress_NonOwner(
        address owner,
        address receiver,
        address unprivilegedAddress_
    ) public {
        vm.assume(owner != unprivilegedAddress_);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));
        vm.assume(unprivilegedAddress_ != address(0));

        vm.prank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address by not owner
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, receiver, proxyAddr);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);
    }

    function testSuccess_safeTransferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address
        factory.safeTransferFrom(owner, receiver, factory.vaultIndex(proxyAddr));

        //Make sure vault itself is owned by receiver
        assertEq(Vault(proxyAddr).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress_)
        public
    {
        vm.assume(owner != unprivilegedAddress_);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));
        vm.assume(unprivilegedAddress_ != address(0));

        vm.prank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address by not owner
        uint256 index = factory.vaultIndex(proxyAddr);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);
    }

    function testSuccess_safeTransferFrom_WithData(address owner, bytes memory data) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address
        factory.safeTransferFrom(owner, receiver, factory.vaultIndex(proxyAddr), data);

        //Make sure vault itself is owned by receiver
        assertEq(Vault(proxyAddr).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), receiver);
        vm.stopPrank();
    }

    function testRevert_safeTransferFrom_WithData_NonOwner(
        address owner,
        address receiver,
        address unprivilegedAddress_,
        bytes memory data
    ) public {
        vm.assume(owner != unprivilegedAddress_);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));
        vm.assume(unprivilegedAddress_ != address(0));

        vm.prank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address by not owner
        uint256 index = factory.vaultIndex(proxyAddr);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, receiver, index, data);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);
    }

    function testSuccess_transferFrom(address owner) public {
        vm.assume(owner != address(0));
        address receiver = address(69); //Cannot be fuzzed, since fuzzer picks often existing deployed contracts, that haven't implemented an onERC721Received

        vm.startPrank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address
        factory.transferFrom(owner, receiver, factory.vaultIndex(proxyAddr));

        //Make sure vault itself is owned by receiver
        assertEq(Vault(proxyAddr).owner(), receiver);

        //Make sure erc721 is owned by receiver
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), receiver);
        vm.stopPrank();
    }

    function testRevert_transferFrom_NonOwner(address owner, address receiver, address unprivilegedAddress_) public {
        vm.assume(owner != unprivilegedAddress_);
        vm.assume(owner != address(0));
        vm.assume(receiver != address(0));
        vm.assume(unprivilegedAddress_ != address(0));

        vm.prank(owner);
        proxyAddr = factory.createVault(0, 0, address(0));

        //Make sure index in erc721 == vaultIndex
        assertEq(Vault(proxyAddr).owner(), factory.ownerOf(1));

        //Make sure vault itself is owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);

        //Transfer vault to another address
        uint256 index = factory.vaultIndex(proxyAddr);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.transferFrom(owner, receiver, index);
        vm.stopPrank();

        //Make sure vault itself is still owned by owner
        assertEq(Vault(proxyAddr).owner(), owner);

        //Make sure erc721 is still owned by owner
        assertEq(factory.ownerOf(factory.vaultIndex(proxyAddr)), owner);
    }

    /* ///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_setNewVaultInfo_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setNewVaultInfo(address(mainRegistry), address(proxyAddr), Constants.upgradeProof1To2);
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_VersionRootIsZero(address mainRegistry_, address logic) public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: version root is zero");
        factory.setNewVaultInfo(mainRegistry_, logic, bytes32(0));
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_LogicAddressIsZero(address mainRegistry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: logic address is zero");
        factory.setNewVaultInfo(mainRegistry_, address(0), versionRoot);
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        mainRegistry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI: no baseCurrency match");
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(false, factory.newVaultInfoSet());
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultInfoWithDifferentBaseCurrencyInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(randomAssetAddress != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        mainRegistry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: randomAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI: no baseCurrency match");
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(false, factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsVaultInfoForFirstTime(address mainRegistry_, address logic) public {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new Factory();
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertTrue(!factory.newVaultInfoSet());

        vm.prank(creatorAddress);
        factory.setNewVaultInfo(mainRegistry_, logic, Constants.upgradeProof1To2);
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertTrue(factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoWithIdenticalMainRegistry(address logic) public {
        vm.assume(logic != address(0));

        assertTrue(!factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultInfoSecondTimeWithIdenticalMainRegistry(address logic)
        public
    {
        vm.assume(logic != address(0));

        assertTrue(!factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
        vm.prank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), logic, Constants.upgradeProof1To2);
        assertTrue(factory.newVaultInfoSet());
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        assertEq(false, factory.newVaultInfoSet());

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        mainRegistry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        mainRegistry2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2);
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
        mainRegistry2 = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        mainRegistry2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2);
        vm.stopPrank();

        assertEq(true, factory.newVaultInfoSet());
    }

    function testRevert_confirmNewVaultInfo_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.confirmNewVaultInfo();
        vm.stopPrank();
    }

    function testSuccess_confirmNewVaultInfo_OwnerConfirmsVaultInfoForFirstTime(address mainRegistry_, address logic)
        public
    {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new Factory();
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));
        assertEq(0, factory.latestVaultVersion());

        vm.prank(creatorAddress);
        factory.setNewVaultInfo(mainRegistry_, logic, Constants.upgradeProof1To2);
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
        factory.setNewVaultInfo(address(mainRegistry), logic, Constants.upgradeProof1To2);
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

    function testRevert_blockVaultVersion_NonOwner(uint16 vaultVersion, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testRevert_blockVaultVersion_BlockNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion || vaultVersion == 0);

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_BVV: Invalid version");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testSuccess_blockVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.prank(creatorAddress);
        factory.blockVaultVersion(vaultVersion);

        assertTrue(factory.vaultVersionBlocked(vaultVersion));
    }

    /* ///////////////////////////////////////////////////////////////
                    VAULT LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testRevert_liquidate_NonVault(address liquidator_, address nonVault) public {
        vm.startPrank(nonVault);
        vm.expectRevert("FTRY: Not a vault");
        factory.liquidate(liquidator_);
        vm.stopPrank();
    }

    function testRevert_liquidate_Paused(address liquidator_, address guardian) public {
        // Given: guardian is the guardian of factory
        vm.prank(creatorAddress);
        factory.changeGuardian(guardian);
        vm.warp(35 days);

        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(0, 0, address(0));
        proxy = Vault(proxyAddr);

        // And: factory is paused
        vm.prank(guardian);
        factory.pause();

        // When: Vault liquidates itself
        // Then: liquidate reverts
        vm.expectRevert("Guardian: liquidate paused");
        vm.prank(address(proxy));
        factory.liquidate(liquidator_);
    }

    function testSuccess_liquidate(address liquidator_) public {
        vm.assume(liquidator_ != vaultOwner);

        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(0, 0, address(0));
        proxy = Vault(proxyAddr);

        vm.prank(address(proxy));
        factory.liquidate(liquidator_);

        assertEq(factory.balanceOf(vaultOwner), 0);
        assertEq(factory.balanceOf(liquidator_), 1);
        uint256 index = factory.vaultIndex(address(proxy));
        assertEq(factory.ownerOf(index), liquidator_);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function testSuccess_allVaultsLength_VaultIdStartFromZero() public {
        assertEq(factory.allVaultsLength(), 0);
    }

    function testSuccess_getCurrentRegistry() public {
        address expectedRegistry = factory.getCurrentRegistry();
        address actualRegistry = address(mainRegistry);

        assertEq(expectedRegistry, actualRegistry);
    }

    /* ///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    /////////////////////////////////////////////////////////////// */

    function testSuccess_setBaseURI(bytes32 uri) public {
        vm.prank(creatorAddress);
        factory.setBaseURI(uri);

        bytes32 expectedUri = factory.baseURI();

        assertEq(expectedUri, uri);
    }

    function testRevert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setBaseURI(uri);
        vm.stopPrank();
    }
}
