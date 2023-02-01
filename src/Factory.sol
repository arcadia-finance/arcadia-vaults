/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import {Proxy} from "./Proxy.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IMainRegistry} from "./interfaces/IMainRegistry.sol";

import {IFactory} from "./interfaces/IFactory.sol";
import {ERC721} from "../lib/solmate/src/tokens/ERC721.sol";
import {Strings} from "./utils/Strings.sol";
import {MerkleProofLib} from "./utils/MerkleProofLib.sol";
import {FactoryGuardian} from "./security/FactoryGuardian.sol";

contract Factory is IFactory, ERC721, FactoryGuardian {
    using Strings for uint256;

    struct vaultVersionInfo {
        address registry;
        address logic;
        bytes32 versionRoot;
        bytes data;
    }

    mapping(uint256 => bool) public vaultVersionBlocked;
    mapping(address => uint256) public vaultIndex;
    mapping(uint256 => vaultVersionInfo) public vaultDetails;

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
    function createVault(uint256 salt, uint16 vaultVersion, address baseCurrency)
        external
        whenCreateNotPaused
        returns (address vault)
    {
        vaultVersion = vaultVersion == 0 ? latestVaultVersion : vaultVersion;

        require(vaultVersion <= latestVaultVersion, "FTRY_CV: Unknown vault version");
        require(!vaultVersionBlocked[vaultVersion], "FTRY_CV: Vault version blocked");

        vault = address(new Proxy{salt: bytes32(salt)}(vaultDetails[vaultVersion].logic));

        IVault(vault).initialize(msg.sender, vaultDetails[vaultVersion].registry, uint16(vaultVersion), baseCurrency);

        allVaults.push(vault);
        vaultIndex[vault] = allVaults.length;

        _mint(msg.sender, allVaults.length);
    }

    /**
     * @notice View function returning if an address is a vault
     * @param vault The address to be checked.
     * @return bool Whether the address is a vault or not.
     */
    function isVault(address vault) public view returns (bool) {
        return vaultIndex[vault] > 0;
    }

    /**
     * @notice Returns the owner of a vault.
     * @param vault The Vault address.
     * @return owner_ The Vault owner.
     * @dev Function does not revert when inexisting vault is passed, but returns zero-address as owner.
     */
    function ownerOfVault(address vault) external view returns (address owner_) {
        owner_ = _ownerOf[vaultIndex[vault]];
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
        require(_ownerOf[vaultIndex[vault]] == msg.sender, "FTRY_UVV: Only Owner");
        require(!vaultVersionBlocked[version], "FTRY_UVV: Vault version blocked");
        uint256 currentVersion = IVault(vault).vaultVersion();

        bool canUpgrade = MerkleProofLib.verify(
            proofs, getVaultVersionRoot(), keccak256(abi.encodePacked(currentVersion, uint256(version)))
        );

        require(canUpgrade, "FTR_UVV: Version not allowed");

        IVault(vault).upgradeVault(
            vaultDetails[version].logic, vaultDetails[version].registry, version, vaultDetails[version].data
        );
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
     * @dev This method transfers a vault not on id but on address and also transfers the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param vault The address of the vault that is about to be transfered.
     */
    function safeTransferFrom(address from, address to, address vault) public {
        uint256 id = vaultIndex[vault];
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id);
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function safeTransferFrom(address from, address to, uint256 id) public override {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id);
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     * @param data additional data, only used for onERC721Received.
     */
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public override {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id, data);
    }

    /**
     * @notice Function used to transfer a vault between users
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param id of the vault that is about to be transfered.
     */
    function transferFrom(address from, address to, uint256 id) public override {
        IVault(allVaults[id - 1]).transferOwnership(to);
        super.transferFrom(from, to, id);
    }

    /*///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to set new contracts to be used for new deployed vaults
     * @dev Changing any of the contracts does NOT change the contracts for existing deployed vaults,
     * unless the vault owner explicitly chooses to upgrade their vault to a newer version
     * If a new Main Registry contract is set, all the BaseCurrencies currently stored in the Factory
     * are checked against the new Main Registry contract. If they do not match, the function reverts.
     * @param registry The contract addres of the Main Registry
     * @param logic The contract address of the Vault logic
     * @param versionRoot The root of the merkle tree of all the compatible vault versions
     */
    function setNewVaultInfo(address registry, address logic, bytes32 versionRoot, bytes calldata data)
        external
        onlyOwner
    {
        require(versionRoot != bytes32(0), "FTRY_SNVI: version root is zero");
        require(logic != address(0), "FTRY_SNVI: logic address is zero");

        //If there is a new Main Registry Contract, Check that baseCurrencies in factory and main registry match
        if (vaultDetails[latestVaultVersion].registry != registry && latestVaultVersion != 0) {
            address oldRegistry = vaultDetails[latestVaultVersion].registry;
            uint256 oldCounter = IMainRegistry(oldRegistry).baseCurrencyCounter();
            uint256 newCounter = IMainRegistry(registry).baseCurrencyCounter();
            require(oldCounter <= newCounter, "FTRY_SNVI: counter mismatch");
            for (uint256 i; i < oldCounter;) {
                require(
                    IMainRegistry(oldRegistry).baseCurrencies(i) == IMainRegistry(registry).baseCurrencies(i),
                    "FTRY_SNVI: no baseCurrency match"
                );
                unchecked {
                    ++i;
                }
            }
        }

        unchecked {
            ++latestVaultVersion;
        }

        vaultDetails[latestVaultVersion].registry = registry;
        vaultDetails[latestVaultVersion].logic = logic;
        vaultDetails[latestVaultVersion].versionRoot = versionRoot;
        vaultDetails[latestVaultVersion].data = data;
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
     * @notice Function called by a Vault at the start of a liquidation to transfer ownership.
     * @param liquidator The contract address of the liquidator.
     */
    function liquidate(address liquidator) external whenLiquidateNotPaused {
        require(isVault(msg.sender), "FTRY: Not a vault");

        uint256 id = vaultIndex[msg.sender];
        address from = _ownerOf[id];
        unchecked {
            _balanceOf[from]--;
            _balanceOf[liquidator]++;
        }

        _ownerOf[id] = liquidator;

        delete getApproved[id];
        emit Transfer(from, liquidator, id);
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
        require(_ownerOf[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
