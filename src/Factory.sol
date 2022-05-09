// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./Proxy.sol";
import "./interfaces/IVault.sol";
import "../lib/solmate/src/tokens/ERC721.sol";

contract Factory is ERC721 {

  struct vaultVersionInfo {
    address registryAddress;
    address logic;
    address stable;
    address stakeContract;
    address interestModule;
  }

    mapping (address => bool) public isVault;
    mapping (uint256 => vaultVersionInfo) public vaultDetails;

    uint256 public currentVaultVersion;
    uint256 public nextVaultVersion;
    bool public newVaultInfoSet;

    address[] public allVaults;
    mapping(address => uint256) public vaultIndex;

    string public baseURI;

    address public owner;

    //Set this on construction?
    address public liquidatorAddress;

    mapping (uint256 => address) public numeraireToStable;

    event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 id);

    modifier onlyOwner() {
      require(msg.sender == owner, "You are not the owner");
      _;
    }

    constructor() ERC721("Arcadia Vault", "ARCADIA") {
        owner = msg.sender;
    }

    function allVaultsLength() external view returns (uint) {
        return allVaults.length;
    }

    function confirmNewVaultInfo() public onlyOwner {
        if (newVaultInfoSet) {
          unchecked {++nextVaultVersion;}
          newVaultInfoSet = false;
        }
    }

    function setLiquidator(address _newLiquidator) public onlyOwner {
        liquidatorAddress = _newLiquidator;
    }

    function setNewVaultInfo(address registryAddress, address logic, address stable, address stakeContract, address interestModule) external onlyOwner {
        vaultDetails[nextVaultVersion].registryAddress = registryAddress;
        vaultDetails[nextVaultVersion].logic = logic;
        vaultDetails[nextVaultVersion].stable = stable;
        vaultDetails[nextVaultVersion].stakeContract = stakeContract;
        vaultDetails[nextVaultVersion].interestModule = interestModule;
        newVaultInfoSet = true;
    }

    /** 
    @notice Function adds numeraire and corresponding stable contract to the factory
    @param numeraire An identifier (uint256) of the Numeraire
    @param stable The contract address of the corresponding ERC20 token pegged to the numeraire
    */
    function addNumeraire(uint256 numeraire, address stable) external onlyOwner {
        numeraireToStable[numeraire] = stable;
    }

    /** 
    @notice Function used to create a Vault
    @dev This is the starting point of the Vault creation process. 
    @param salt A salt to be used to generate the hash.
    */
    function createVault(uint256 salt) external returns (address vault) {
        bytes memory initCode = type(Proxy).creationCode;
        bytes memory byteCode = abi.encodePacked(initCode, abi.encode(vaultDetails[currentVaultVersion].logic));

        assembly {
            vault := create2(0, add(byteCode, 32), mload(byteCode), salt)
        }
        IVault(vault).initialize(msg.sender, 
                                  vaultDetails[currentVaultVersion].registryAddress, 
                                  vaultDetails[currentVaultVersion].stable, 
                                  vaultDetails[currentVaultVersion].stakeContract, 
                                  vaultDetails[currentVaultVersion].interestModule);
        
        
        allVaults.push(vault);
        isVault[vault] = true;

        _mint(msg.sender, allVaults.length -1);
        emit VaultCreated(vault, msg.sender, allVaults.length);
    }

  /** 
    @notice Function used to transfer a vault between users
    @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the vault proxy contract to the new owner.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function safeTransferFrom(address from, address to, uint256 id) override public {
        _safeTransferFrom(from, to, id);
    }

  /** 
    @notice Internal function used to transfer a vault between users
    @dev This function is used to transfer a vault between users.
         Overriding to transfer ownership of linked vault.
    @param from sender.
    @param to target.
    @param id of the vault that is about to be transfered.
  */
    function _safeTransferFrom(address from, address to, uint256 id) internal {
        transferFrom(from, to, id);

        IVault(allVaults[id]).transferOwnership(to);
        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /** 
    @notice Function used by a keeper to start the liquidation of a vualt.
    @dev This function is called by an external user or a bbot to start the liquidation process of a vault.
    @param vault Vault that needs to get liquidated.
  */
    function liquidate(address vault) external {
        _liquidate(vault, msg.sender);
    }

        /** 
    @notice Internal function used to start the liquidation of a vualt.
    @dev 
    @param vault Vault that needs to get liquidated.
    @param sender The msg.sender of the liquidator. Also the 'keeper'
  */
    function _liquidate(address vault, address sender) internal {
        require(IVault(vault).liquidateVault(sender, liquidatorAddress), "FTRY: Vault liquidation failed");
        // Vault version read via Ivault?
         IVault(allVaults[vaultIndex[vault]]).transferOwnership(liquidatorAddress);
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
    
    //TODO: add right tokenUri data
   function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (ownerOf[tokenId] == address(0)) {
            revert("Token does not exist");
        }

        return "ipfs://";
    }

  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

}
