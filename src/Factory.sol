/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./Proxy.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IMainRegistry.sol";
import "../lib/solmate/src/tokens/ERC721.sol";
import "./utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Factory is ERC721, Ownable {
    using Strings for uint256;

    struct vaultVersionInfo {
        address registryAddress;
        address logic;
        address stakeContract;
        address interestModule;
    }

    mapping(address => bool) public isVault;
    mapping(uint256 => vaultVersionInfo) public vaultDetails;

    uint256 public currentVaultVersion;
    bool public factoryInitialised;
    bool public newVaultInfoSet;

    address[] public allVaults;
    mapping(address => uint256) public vaultIndex;

    string public baseURI;

    address public liquidatorAddress;

    uint256 public numeraireCounter;
    mapping(uint256 => address) public numeraireToStable;

    event VaultCreated(
        address indexed vaultAddress,
        address indexed owner,
        uint256 id
    );

    constructor() ERC721("Arcadia Vault", "ARCADIA") {}

    /**
    @notice Function returns the total number of vaults
    @return numberOfVaults The total number of vaults 
  */
    function allVaultsLength() external view returns (uint256 numberOfVaults) {
        numberOfVaults = allVaults.length;
    }

    /**
    @notice Function to set a new contract for the liquidation logic
    @dev Since vaults to be liquidated, together with the open debt, are transferred to the protocol,
         New logic can be set without needing to increment the vault version.
    @param _newLiquidator The new liquidator contract
  */
    function setLiquidator(address _newLiquidator) public onlyOwner {
        liquidatorAddress = _newLiquidator;
    }

    /**
    @notice Function confirms the new contracts to be used for new deployed vaults
    @dev Two step function to confirm new logic to be used for new deployed vaults.
         Changing any of the contracts does NOT change the contracts for already deployed vaults,
         unless the vault owner explicitly chooses to upgrade their vault version to a newer version
         ToDo Add a time lock between setting a new vault version, and confirming a new vault version
         If no new vault info is being set (newVaultInfoSet is false), this function will not do anything
         The variable factoryInitialised is set to true as soon as one vault version is confirmed
  */
    function confirmNewVaultInfo() public onlyOwner {
        if (newVaultInfoSet) {
            unchecked {
                ++currentVaultVersion;
            }
            newVaultInfoSet = false;
            if (!factoryInitialised) {
                factoryInitialised = true;
            }
        }
    }

    /**
    @notice Function to set new contracts to be used for new deployed vaults
    @dev Two step function to confirm new logic to be used for new deployed vaults.
         Changing any of the contracts does NOT change the contracts for already deployed vaults,
         unless the vault owner explicitly choose to upgrade their vault version to a newer version
         ToDo Add a time lock between setting a new vault version, and confirming a new vault version
         Changing any of the logic contracts with this function does NOT immediately take effect,
         only after the function 'confirmNewVaultInfo' is called.
         If a new Main Registry contract is set, all the Numeraires currently stored in the Factory 
         (and the corresponding Stable Contracts) must also be stored in the new Main registry contract.
    @param registryAddress The contract addres of the Main Registry
    @param logic The contract address of the Vault logic
    @param stakeContract The contract addres of the Staking Contract
    @param interestModule The contract address of the Interest Rate Module
  */
    function setNewVaultInfo(
        address registryAddress,
        address logic,
        address stakeContract,
        address interestModule
    ) external onlyOwner {
        vaultDetails[currentVaultVersion + 1].registryAddress = registryAddress;
        vaultDetails[currentVaultVersion + 1].logic = logic;
        vaultDetails[currentVaultVersion + 1].stakeContract = stakeContract;
        vaultDetails[currentVaultVersion + 1].interestModule = interestModule;
        newVaultInfoSet = true;

        //If there is a new Main Registry Contract, Check that numeraires in factory and main registry match
        if (
            factoryInitialised &&
            vaultDetails[currentVaultVersion].registryAddress != registryAddress
        ) {
            address mainRegistryStableAddress;
            for (uint256 i; i < numeraireCounter; ) {
                (, , , , mainRegistryStableAddress, ) = IMainRegistry(
                    registryAddress
                ).numeraireToInformation(i);
                require(
                    mainRegistryStableAddress == numeraireToStable[i],
                    "FTRY_SNVI:No match numeraires MR"
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
  @notice Function adds numeraire and corresponding stable contract to the factory
  @dev Numeraires can only be added by the latest Main Registry
  @param numeraire An identifier (uint256) of the Numeraire
  @param stable The contract address of the corresponding ERC20 token pegged to the numeraire
  */
    function addNumeraire(uint256 numeraire, address stable) external {
        require(
            vaultDetails[currentVaultVersion].registryAddress == msg.sender,
            "FTRY_AN: Add Numeraires via MR"
        );
        numeraireToStable[numeraire] = stable;
        unchecked {
            ++numeraireCounter;
        }
    }

    /**
  @notice Returns address of the most recent Main Registry
  @return registry The contract addres of the Main Registry of the latest Vault Version
  */
    function getCurrentRegistry() external view returns (address registry) {
        registry = vaultDetails[currentVaultVersion].registryAddress;
    }

    /**
  @notice Function used to create a Vault
  @dev This is the starting point of the Vault creation process. Safe to cast a uint256 to a bytes32 since the space of both is 2^256.
  @param salt A salt to be used to generate the hash.
  @param numeraire An identifier (uint256) of the Numeraire
  */
    function createVault(uint256 salt, uint256 numeraire)
        external
        virtual
        returns (address vault)
    {
        require(
            numeraire <= numeraireCounter - 1,
            "FTRY_CV: Unknown Numeraire"
        );

        vault = address(
            new Proxy{salt: bytes32(salt)}(
                vaultDetails[currentVaultVersion].logic
            )
        );

        IVault(vault).initialize(
            msg.sender,
            vaultDetails[currentVaultVersion].registryAddress,
            numeraire,
            numeraireToStable[numeraire],
            vaultDetails[currentVaultVersion].stakeContract,
            vaultDetails[currentVaultVersion].interestModule
        );

        allVaults.push(vault);
        isVault[vault] = true;
        vaultIndex[vault] = allVaults.length - 1;

        _mint(msg.sender, allVaults.length - 1);
        emit VaultCreated(vault, msg.sender, allVaults.length - 1);
    }

    /**
    @notice Function used to transfer a vault between users
    @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        _safeTransferFrom(from, to, id);
    }

    /** 
    @notice Function used to transfer a vault between users
    @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
    @param data additional data, only used for onERC721Received.
  */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public override {
        _safeTransferFrom(from, to, id, data);
    }

    /** 
    @notice Function used to transfer a vault between users
    @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        _transferFrom(from, to, id);
    }

    /**
    @notice Internal function used to transfer a vault between users
    @dev This function is used to transfer a vault between users.
         Overriding to transfer ownership of linked vault.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) internal {
        IVault(allVaults[id]).transferOwnership(to);
        super.transferFrom(from, to, id);
        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    ""
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
    @notice Internal function used to transfer a vault between users
    @dev This function is used to transfer a vault between users.
         Overriding to transfer ownership of linked vault.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
    @param data additional data, only used for onERC721Received.
    */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) internal {
        IVault(allVaults[id]).transferOwnership(to);
        super.transferFrom(from, to, id);
        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    data
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /** 
    @notice Internal function used to transfer a vault between users
    @dev This function is used to transfer a vault between users.
         Overriding to transfer ownership of linked vault.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function _transferFrom(
        address from,
        address to,
        uint256 id
    ) internal {
        IVault(allVaults[id]).transferOwnership(to);
        super.transferFrom(from, to, id);
    }

    /**
    @notice Function used by a keeper to start the liquidation of a vault.
    @dev This function is called by an external user or a bbot to start the liquidation process of a vault.
    @param vault Vault that needs to get liquidated.
  */
    function liquidate(address vault) external virtual {
        require(isVault[vault], "FTRY: Not a vault");
        _liquidate(vault, msg.sender);
    }

    /**
    @notice Internal function used to start the liquidation of a vault.
    @dev 
    @param vault Vault that needs to get liquidated.
    @param sender The msg.sender of the liquidator. Also the 'keeper'
  */
    function _liquidate(address vault, address sender) internal {
        require(
            IVault(vault).liquidateVault(sender, liquidatorAddress),
            "FTRY: Vault liquidation failed"
        );
        // Vault version read via Ivault?
        IVault(vault).transferOwnership(liquidatorAddress);
        _liquidateTransfer(vault);
    }

    /**
    @notice Helper transfer function that allows the contract to transfer ownership of the erc721.
    @dev This function is called by the contract when a vault is liquidated. 
         This includes a transfer of ownership of the vault.
         We circumvent the ERC721 transfer function.
    @param vault Vault that needs to get transfered.
  */
    function _liquidateTransfer(address vault) internal {
        address from = ownerOf[vaultIndex[vault]];
        unchecked {
            balanceOf[from]--;
            balanceOf[liquidatorAddress]++;
        }

        ownerOf[vaultIndex[vault]] = liquidatorAddress;

        delete getApproved[vaultIndex[vault]];
        emit Transfer(from, liquidatorAddress, vaultIndex[vault]);
    }

    /**
    @notice Function that stores a new base URI.
    @dev tokenURI's of Arcadia Vaults are not meant to be immutable
        and might be updated later to allow users to
        choose/create their own vault art,
        as such no URI freeze is added.
    @param newBaseURI the new base URI to store
  */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
    @notice Function that returns the token URI as defined in the erc721 standard.
    @param tokenId The id if the vault
    @return uri The token uri.
  */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory uri)
    {
        require(
            ownerOf[tokenId] != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
