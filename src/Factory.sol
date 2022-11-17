/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./Proxy.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IMainRegistry.sol";
import "../lib/solmate/src/tokens/ERC721.sol";
import "./utils/Strings.sol";
import "./utils/MerkleProofLib.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Factory is ERC721, Ownable {
    using Strings for uint256;

    struct vaultVersionInfo {
        address registry;
        address logic;
        bytes32 versionRoot;
    }

    mapping(uint256 => bool) public vaultVersionBlocked;
    mapping(address => uint256) public vaultIndex;
    mapping(uint256 => vaultVersionInfo) public vaultDetails;

    bool public newVaultInfoSet;
    uint16 public latestVaultVersion;
    string public baseURI;

    address[] public allVaults;

    constructor() ERC721("Arcadia Vault", "ARCADIA") {}

    /*///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function used to create a Vault
     * @dev This is the starting point of the Vault creation process. Safe to cast a uint256 to a bytes32 since the space of both is 2^256.
     * @param salt A salt to be used to generate the hash.
     * @param vaultVersion The Vault version.
     * @return vault The contract address of the proxy contract of the newly deployed vault.
     */
    function createVault(uint256 salt, uint256 vaultVersion) external returns (address vault) {
        vaultVersion = vaultVersion == 0 ? latestVaultVersion : vaultVersion;

        require(vaultVersion <= latestVaultVersion, "FTRY_CV: Unknown vault version");
        require(vaultVersionBlocked[vaultVersion] == false, "FTRY_CV: This vault version cannot be created");

        vault = address(new Proxy{salt: bytes32(salt)}(vaultDetails[vaultVersion].logic));

        IVault(vault).initialize(msg.sender, vaultDetails[vaultVersion].registry, uint16(vaultVersion));

        allVaults.push(vault);
        vaultIndex[vault] = allVaults.length;

        _mint(msg.sender, allVaults.length);
    }

    /**
     * @notice View function to see if an address is a vault
     * @dev Function is used to verify if certain calls are to be made to an actual vault or not.
     * @param vaultAddr The address to be checked.
     * @return bool whether the address is a vault or not.
     */
    function isVault(address vaultAddr) public view returns (bool) {
        return vaultIndex[vaultAddr] > 0;
    }

    /**
     * @notice This function allows vault owners to upgrade the logic of the vault.
     * @dev As each vault is a proxy, the implementation of the proxy can be changed by the owner of the vault.
     * Checks are done such that only compatible versions can be upgraded to.
     * Merkle proofs and their leaves can be found on https://www.github.com/arcadia-finance.
     * @param vault Vault that needs to get updated.
     * @param version The vaultversion to upgrade to.
     * @param proofs The merkle proofs that prove the compatibility of the upgrade.
     */
    function upgradeVaultVersion(address vault, uint16 version, bytes32[] calldata proofs) external {
        require(ownerOf[vaultIndex[vault]] == msg.sender, "FTRY_UVV: You are not the owner");
        uint256 currentVersion = IVault(vault).vaultVersion();

        bool canUpgrade = MerkleProofLib.verify(
            proofs, getVaultVersionRoot(), keccak256(abi.encodePacked(currentVersion, uint256(version)))
        );

        require(canUpgrade, "FTR_UVV: Cannot upgrade to this version");

        address newImplementation = vaultDetails[version].logic;

        IVault(vault).upgradeVault(newImplementation, version);
    }

    /**
     * @notice Function to get the latest and current versioning root.
     * @dev The versioning root is the root of the merkle tree of all the compatible vault versions.
     * The root is updated every time a new vault version is confirmed. The root is used to verify the
     * proofs when a vault is being upgraded.
     * @return The latest and current versioning root.
     */
    function getVaultVersionRoot() public view returns (bytes32) {
        return vaultDetails[latestVaultVersion].versionRoot;
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function safeTransferFrom(address from, address to, uint256 id) public override {
        _safeTransferFrom(from, to, id);
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     * @param data additional data, only used for onERC721Received.
     */
    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) public override {
        _safeTransferFrom(from, to, id, data);
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function transferFrom(address from, address to, uint256 id) public override {
        _transferFrom(from, to, id);
    }

    /**
     * @notice Internal function used to transfer a vault between users
     * @dev This function is used to transfer a vault between users.
     * Overriding to transfer ownership of linked vault.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function _safeTransferFrom(address from, address to, uint256 id) internal {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.transferFrom(from, to, id);
        require(
            to.code.length == 0
                || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "")
                    == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
     * @notice Internal function used to transfer a vault between users
     * @dev This function is used to transfer a vault between users.
     * Overriding to transfer ownership of linked vault.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     * @param data additional data, only used for onERC721Received.
     */
    function _safeTransferFrom(address from, address to, uint256 id, bytes memory data) internal {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.transferFrom(from, to, id);
        require(
            to.code.length == 0
                || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data)
                    == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
     * @notice Internal function used to transfer a vault between users
     * @dev This function is used to transfer a vault between users.
     * Overriding to transfer ownership of linked vault.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function _transferFrom(address from, address to, uint256 id) internal {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.transferFrom(from, to, id);
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to set new contracts to be used for new deployed vaults
     * @dev Two step function to confirm new logic to be used for new deployed vaults.
     * Changing any of the contracts does NOT change the contracts for already deployed vaults,
     * unless the vault owner explicitly choose to upgrade their vault version to a newer version
     * ToDo Add a time lock between setting a new vault version, and confirming a new vault version
     * Changing any of the logic contracts with this function does NOT immediately take effect,
     * only after the function 'confirmNewVaultInfo' is called.
     * If a new Main Registry contract is set, all the BaseCurrencies currently stored in the Factory
     * (and the corresponding Liquidity Pool Contracts) must also be stored in the new Main registry contract.
     * @param registry The contract addres of the Main Registry
     * @param logic The contract address of the Vault logic
     * @param versionRoot The root of the merkle tree of all the compatible vault versions
     */
    function setNewVaultInfo(address registry, address logic, bytes32 versionRoot) external onlyOwner {
        require(versionRoot != bytes32(0), "FTRY_SNVI: version root is zero");
        require(logic != address(0), "FTRY_SNVI: logic address is zero");

        vaultDetails[latestVaultVersion + 1].registry = registry;
        vaultDetails[latestVaultVersion + 1].logic = logic;
        vaultDetails[latestVaultVersion + 1].versionRoot = versionRoot;
        newVaultInfoSet = true;

        //If there is a new Main Registry Contract, Check that baseCurrencies in factory and main registry match
        if (vaultDetails[latestVaultVersion].registry != registry && latestVaultVersion != 0) {
            address oldRegistry = vaultDetails[latestVaultVersion].registry;
            uint256 oldCounter = IMainRegistry(oldRegistry).baseCurrencyCounter();
            uint256 newCounter = IMainRegistry(registry).baseCurrencyCounter();
            require(oldCounter <= newCounter, "FTRY_SNVI:No match baseCurrencies MR");
            for (uint256 i; i < oldCounter;) {
                require(
                    IMainRegistry(oldRegistry).baseCurrencies(i) == IMainRegistry(registry).baseCurrencies(i),
                    "FTRY_SNVI:No match baseCurrencies MR"
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Function confirms the new contracts to be used for new deployed vaults
     * @dev Two step function to confirm new logic to be used for new deployed vaults.
     * Changing any of the contracts does NOT change the contracts for already deployed vaults,
     * unless the vault owner explicitly chooses to upgrade their vault version to a newer version
     * ToDo Add a time lock between setting a new vault version, and confirming a new vault version
     * If no new vault info is being set (newVaultInfoSet is false), this function will not do anything
     * The variable factoryInitialised is set to true as soon as one vault version is confirmed
     */
    function confirmNewVaultInfo() public onlyOwner {
        if (newVaultInfoSet) {
            unchecked {
                ++latestVaultVersion;
            }
            newVaultInfoSet = false;
        }
    }

    /**
     * @notice Function to block a certain vault logic version from being created as a new vault.
     * @dev Should any vault logic version be phased out,
     * this function can be used to block it from being created for new vaults.
     * @param version The vault version to be phased out.
     */
    function blockVaultVersion(uint256 version) external onlyOwner {
        require(version > 0 && version <= latestVaultVersion, "FTRY_BVV: Invalid version");
        vaultVersionBlocked[version] = true;
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT LIQUIDATION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function used by a keeper to start the liquidation of a vault.
     * @dev This function is called by an external user or a bbot to start the liquidation process of a vault.
     * @param vault Vault that needs to get liquidated.
     */
    function liquidate(address vault) external {
        require(isVault(vault), "FTRY: Not a vault");
        _liquidate(vault, msg.sender);
    }

    /**
     * @notice Internal function used to start the liquidation of a vault.
     * @dev
     * @param vault Vault that needs to get liquidated.
     * @param sender The msg.sender of the liquidator. Also the 'keeper'
     */
    function _liquidate(address vault, address sender) internal {
        (bool success, address liquidator) = IVault(vault).liquidateVault(sender);
        require(success, "FTRY: Vault liquidation failed");
        // Vault version read via Ivault?
        IVault(vault).transferOwnership(liquidator);
        _liquidateTransfer(vault, liquidator);
    }

    /**
     * @notice Helper transfer function that allows the contract to transfer ownership of the erc721.
     * @dev This function is called by the contract when a vault is liquidated.
     * This includes a transfer of ownership of the vault.
     * We circumvent the ERC721 transfer function.
     * @param vault Vault that needs to get transfered.
     */
    function _liquidateTransfer(address vault, address liquidator) internal {
        address from = ownerOf[vaultIndex[vault]];
        unchecked {
            balanceOf[from]--;
            balanceOf[liquidator]++;
        }

        ownerOf[vaultIndex[vault]] = liquidator;

        delete getApproved[vaultIndex[vault]];
        emit Transfer(from, liquidator, vaultIndex[vault]);
    }

    /*///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function returns the total number of vaults
     * @return numberOfVaults The total number of vaults
     */
    function allVaultsLength() external view returns (uint256 numberOfVaults) {
        numberOfVaults = allVaults.length;
    }

    /**
     * @notice Returns address of the most recent Main Registry
     * @return registry The contract addres of the Main Registry of the latest Vault Version
     */
    function getCurrentRegistry() external view returns (address registry) {
        registry = vaultDetails[latestVaultVersion].registry;
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that stores a new base URI.
     * @dev tokenURI's of Arcadia Vaults are not meant to be immutable
     * and might be updated later to allow users to
     * choose/create their own vault art,
     * as such no URI freeze is added.
     * @param newBaseURI the new base URI to store
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @notice Function that returns the token URI as defined in the erc721 standard.
     * @param tokenId The id if the vault
     * @return uri The token uri.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        require(ownerOf[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
