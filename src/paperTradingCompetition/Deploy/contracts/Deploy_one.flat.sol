
/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

////import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*///////////////////////////////////////////////////////////////
                             EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                              EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IFactory {
  function isVault(address vaultAddress) external view returns (bool);
  function safeTransferFrom(address from, address to, uint256 id) external;
  function liquidate(address vault) external returns (bool);
  function vaultIndex(address vaultAddress) external view returns (uint256);
  function getCurrentRegistry() view external returns (address);
  function addNumeraire(uint256 numeraire, address stable) external;
  function numeraireCounter() external returns (uint256);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.8.0;

////import "../../lib/solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {

  constructor(string memory name, string memory symbol, uint8 _decimalsInput) ERC20(name, symbol, _decimalsInput) {
  }

  function mint(address to, uint256 amount) public virtual {
      _mint(to, amount);
  }

  function burn(uint256 amount) public {
      _burn(msg.sender, amount);
  }

}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.8.0;

////import "./mockups/ERC20SolmateMock.sol";
////import "./interfaces/IFactory.sol";
////import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Stable is ERC20, Ownable {

  address public liquidator;
  address public factory;

  modifier onlyVault {
      require(IFactory(factory).isVault(msg.sender), "Only a vault can mint!");
      _;
  }

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address liquidatorAddress, address _factory) ERC20(name, symbol, _decimalsInput) {
      liquidator = liquidatorAddress;
      factory = _factory;
  }

  function setFactory(address _factory) public onlyOwner {
      factory = _factory;
  }

  function mint(address to, uint256 amount) public onlyVault {
      _mint(to, amount);
  }

  function setLiquidator(address liq) public onlyOwner {
      liquidator = liq;
  }

  function burn(uint256 amount) public {
      _burn(msg.sender, amount);
  }
function safeBurn(address from, uint256 amount) public returns (bool) {
    require(msg.sender == from || msg.sender == liquidator);
    _burn(from, amount);

    return true;
  }

}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IVault {
  function owner() external view returns (address);
  function transferOwnership(address newOwner) external;
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address interestModule) external;
  function liquidateVault(address liquidationKeeper, address liquidator) external returns (bool);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: AGPL-3.0-only
pragma solidity >=0.8.6;

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// @dev Note that balanceOf does not revert if passed the zero address, in defiance of the ERC.
abstract contract ERC721 {
    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*///////////////////////////////////////////////////////////////
                          METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*///////////////////////////////////////////////////////////////
                            ERC721 STORAGE                        
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) public ownerOf;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*///////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            balanceOf[from]--;

            balanceOf[to]++;
        }

        ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            balanceOf[owner]--;
        }

        delete ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IMainRegistry {
  function addAsset(address, uint256[] memory) external;
  function getTotalValue(
              address[] calldata _assetAddresses, 
              uint256[] calldata _assetIds,
              uint256[] calldata _assetAmounts,
              uint256 numeraire
            ) external view returns (uint256);
  function factoryAddress() external view returns (address);
  function numeraireToInformation(uint256 numeraire) external view returns (uint64, uint64, address, address, address, string memory);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;


contract Proxy {

    struct AddressSlot {
        address value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);


    constructor(address _logic) payable {
        //gas: removed assert
        //assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _setImplementation(_logic);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view returns (address) {
        return getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        //gas: removed require: no funds can be of loss (delegate calls to deposit will fail)
        //require(isContract(newImplementation), "ERC1967: new implementation is not a contract");
        getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../../interfaces/IVault.sol";

interface IVaultPaperTrading is IVault {
  function _stable() external view returns (address);
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address interestModule, address tokenShop) external;
  function debt() external returns(uint128 _openDebt, uint16 _collThres, uint8 _liqThres, uint64 _yearlyInterestRate, uint32 _lastBlock, uint8 _numeraire);
  function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external;
  function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./Proxy.sol";
////import "./interfaces/IVault.sol";
////import "./interfaces/IMainRegistry.sol";
////import "../lib/solmate/src/tokens/ERC721.sol";
////import "./utils/Strings.sol";
////import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Factory is ERC721, Ownable {
  using Strings for uint256;

  struct vaultVersionInfo {
    address registryAddress;
    address logic;
    address stakeContract;
    address interestModule;
  }

  mapping (address => bool) public isVault;
  mapping (uint256 => vaultVersionInfo) public vaultDetails;

  uint256 public currentVaultVersion;
  bool public factoryInitialised;
  bool public newVaultInfoSet;

  address[] public allVaults;
  mapping(address => uint256) public vaultIndex;

  string public baseURI;

  address public liquidatorAddress;

  uint256 public numeraireCounter;
  mapping (uint256 => address) public numeraireToStable;

  event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 id);

  constructor() ERC721("Arcadia Vault", "ARCADIA") { }

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
      unchecked {++currentVaultVersion;}
      newVaultInfoSet = false;
      if(!factoryInitialised) {
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
  function setNewVaultInfo(address registryAddress, address logic, address stakeContract, address interestModule) external onlyOwner {
    vaultDetails[currentVaultVersion+1].registryAddress = registryAddress;
    vaultDetails[currentVaultVersion+1].logic = logic;
    vaultDetails[currentVaultVersion+1].stakeContract = stakeContract;
    vaultDetails[currentVaultVersion+1].interestModule = interestModule;
    newVaultInfoSet = true;

    //If there is a new Main Registry Contract, Check that numeraires in factory and main registry match
    if (factoryInitialised && vaultDetails[currentVaultVersion].registryAddress != registryAddress) {
      address mainRegistryStableAddress;
      for (uint256 i; i < numeraireCounter;) {
        (,,,,mainRegistryStableAddress,) = IMainRegistry(registryAddress).numeraireToInformation(i);
        require(mainRegistryStableAddress == numeraireToStable[i], "FTRY_SNVI:No match numeraires MR");
        unchecked {++i;}
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
    require(vaultDetails[currentVaultVersion].registryAddress == msg.sender, "FTRY_AN: Add Numeraires via MR");
    numeraireToStable[numeraire] = stable;
    unchecked {++numeraireCounter;}
  }

  /** 
  @notice Returns address of the most recent Main Registry
  @return registry The contract addres of the Main Registry of the latest Vault Version
  */
  function getCurrentRegistry() view external returns (address registry) {
    registry = vaultDetails[currentVaultVersion].registryAddress;
  }

  /** 
  @notice Function used to create a Vault
  @dev This is the starting point of the Vault creation process. 
  @param salt A salt to be used to generate the hash.
  @param numeraire An identifier (uint256) of the Numeraire
  */
  function createVault(uint256 salt, uint256 numeraire) external virtual returns (address vault) {
    require(numeraire <= numeraireCounter - 1, "FTRY_CV: Unknown Numeraire");

    bytes memory initCode = type(Proxy).creationCode;
    bytes memory byteCode = abi.encodePacked(initCode, abi.encode(vaultDetails[currentVaultVersion].logic));

    assembly {
      vault := create2(0, add(byteCode, 32), mload(byteCode), salt)
    }
    IVault(vault).initialize(msg.sender, 
                              vaultDetails[currentVaultVersion].registryAddress, 
                              numeraireToStable[numeraire], 
                              vaultDetails[currentVaultVersion].stakeContract, 
                              vaultDetails[currentVaultVersion].interestModule);
    
    
    allVaults.push(vault);
    isVault[vault] = true;

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
    IVault(allVaults[id]).transferOwnership(to);
    transferFrom(from, to, id);
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
  function tokenURI(uint256 tokenId) public view override returns (string memory uri) {

    require(ownerOf[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
  }

  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.8.0;

////import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract SimplifiedChainlinkOracle is Ownable {

	uint80 private roundId;
	int256 private answer;
	uint256 private startedAt;
	uint256 private updatedAt;
	uint80 private answeredInRound;

  uint8 public decimals;
  string public description;

  constructor (uint8 _decimals, string memory _description) {
		decimals = _decimals;
		description = _description;
  }

  function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
    return (roundId, answer, startedAt, updatedAt, answeredInRound);
  }

	function setAnswer(int256 _answer) external onlyOwner {
		answer = _answer;
	}
  
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.8.0;

////import "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract StableOracle is Ownable {

	uint80 private roundId;
	int256 private answer;
	uint256 private startedAt;
	uint256 private updatedAt;
	uint80 private answeredInRound;

  uint8 public decimals;
  string public description;

  constructor (uint8 _decimals, string memory _description) {
		decimals = _decimals;
		description = _description;
		answer = int256(10 ** _decimals);
  }

  function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
    return (roundId, answer, startedAt, updatedAt, answeredInRound);
  }
  
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED

pragma solidity ^0.8.0;

library Constants {
    // Math
    uint256 internal constant UsdNumeraire = 0;
    uint256 internal constant EthNumeraire = 1;
    uint256 internal constant SafemoonNumeraire = 2;

    uint256 internal constant ethDecimals = 12;
    uint256 internal constant ethCreditRatingUsd = 2;
    uint256 internal constant ethCreditRatingBtc = 0;
    uint256 internal constant ethCreditRatingEth = 1;
    uint256 internal constant snxDecimals = 14;
    uint256 internal constant snxCreditRatingUsd = 0;
    uint256 internal constant snxCreditRatingEth = 0;
    uint256 internal constant linkDecimals = 4;
    uint256 internal constant linkCreditRatingUsd = 2;
    uint256 internal constant linkCreditRatingEth = 2;
    uint256 internal constant safemoonDecimals = 18;
    uint256 internal constant safemoonCreditRatingUsd = 0;
    uint256 internal constant safemoonCreditRatingEth = 0;
    uint256 internal constant baycCreditRatingUsd = 4;
    uint256 internal constant baycCreditRatingEth = 3;
    uint256 internal constant maycCreditRatingUsd = 0;
    uint256 internal constant maycCreditRatingEth = 0;
    uint256 internal constant dickButsCreditRatingUsd = 0;
    uint256 internal constant dickButsCreditRatingEth = 0;
    uint256 internal constant interleaveCreditRatingUsd = 0;
    uint256 internal constant interleaveCreditRatingEth = 0;
    uint256 internal constant wbaycDecimals = 16;
    uint256 internal constant wmaycDecimals = 14;

    uint256 internal constant oracleEthToUsdDecimals = 8;
    uint256 internal constant oracleLinkToUsdDecimals = 8;
    uint256 internal constant oracleSnxToEthDecimals = 18;
    uint256 internal constant oracleWbaycToEthDecimals = 18;
    uint256 internal constant oracleWmaycToUsdDecimals = 8;
    uint256 internal constant oracleInterleaveToEthDecimals = 10;
    uint256 internal constant oracleStableToUsdDecimals = 12;
    uint256 internal constant oracleStableEthToEthDecimals = 14;

    uint256 internal constant oracleEthToUsdUnit = 10**oracleEthToUsdDecimals;
    uint256 internal constant oracleLinkToUsdUnit = 10**oracleLinkToUsdDecimals;
    uint256 internal constant oracleSnxToEthUnit = 10**oracleSnxToEthDecimals;
    uint256 internal constant oracleWbaycToEthUnit = 10**oracleWbaycToEthDecimals;
    uint256 internal constant oracleWmaycToUsdUnit = 10**oracleWmaycToUsdDecimals;
    uint256 internal constant oracleInterleaveToEthUnit = 10**oracleInterleaveToEthDecimals;
    uint256 internal constant oracleStableToUsdUnit = 10**oracleStableToUsdDecimals;
    uint256 internal constant oracleStableEthToEthUnit = 10**oracleStableEthToEthDecimals;

    uint256 internal constant usdDecimals = 14;
    uint256 internal constant stableDecimals = 18;
    uint256 internal constant stableEthDecimals = 18;

    uint256 internal constant WAD = 1e18;
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../Stable.sol";

contract StablePaperTrading is Stable {

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address liquidatorAddress, address _factory) Stable(name, symbol, _decimalsInput, liquidatorAddress, _factory) {}

  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    if (from == to) {
      return true; 
    } else {
      return super.transferFrom(from, to, amount);
    }
  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../Factory.sol";
////import "./interfaces/IVaultPaperTrading.sol";

contract FactoryPaperTrading is Factory {
  address tokenShop;

  /** 
    @notice returns contract address of individual vaults
    @param id The id of the Vault
    @return vaultAddress The contract address of the individual vault
  */
  function getVaultAddress(uint256 id) external view returns(address vaultAddress) {
    vaultAddress = allVaults[id];
  }

  /** 
    @notice Function to set a new contract for the tokenshop logic
    @param _tokenShop The new tokenshop contract
  */
  function setTokenShop(address _tokenShop) public onlyOwner {
    tokenShop = _tokenShop;
  }

  /** 
  @notice Function used to create a Vault
  @dev This is the starting point of the Vault creation process. 
  @param salt A salt to be used to generate the hash.
  @param numeraire An identifier (uint256) of the Numeraire
*/
  function createVault(uint256 salt, uint256 numeraire) external override returns (address vault) {
    bytes memory initCode = type(Proxy).creationCode;
    bytes memory byteCode = abi.encodePacked(initCode, abi.encode(vaultDetails[currentVaultVersion].logic));

    assembly {
        vault := create2(0, add(byteCode, 32), mload(byteCode), salt)
    }

    allVaults.push(vault);
    isVault[vault] = true;

    IVaultPaperTrading(vault).initialize(msg.sender, 
                              vaultDetails[currentVaultVersion].registryAddress, 
                              numeraireToStable[numeraire], 
                              vaultDetails[currentVaultVersion].stakeContract, 
                              vaultDetails[currentVaultVersion].interestModule,
                              tokenShop);


    _mint(msg.sender, allVaults.length -1);
    emit VaultCreated(vault, msg.sender, allVaults.length);
  }

}

/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_one.sol
*/

////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >0.8.10;


////import "../../FactoryPaperTrading.sol";
////import "../../../Proxy.sol";
////import "../../StablePaperTrading.sol";
////import "../../../utils/Constants.sol";
////import "../../Oracles/StableOracle.sol";
////import "../../../mockups/SimplifiedChainlinkOracle.sol";
////import "../../../utils/Strings.sol";

contract DeployContractsOne  {

  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function deployFact() public returns (address) {
    FactoryPaperTrading fact = new FactoryPaperTrading();
    fact.transferOwnership(msg.sender);
    return address(fact);
  }

  function deployStable(string calldata a, string calldata b, uint8 c, address d, address e) public returns (address) {
    StablePaperTrading stab = new StablePaperTrading(a, b, c, d, e);
    stab.transferOwnership(msg.sender);
    return address(stab);
  }

  function deployOracle(uint8 a, string calldata b) external returns (address) {
    SimplifiedChainlinkOracle orac = new SimplifiedChainlinkOracle(a, b);
    orac.transferOwnership(msg.sender);
    return address(orac);
  }

  function deployOracleStable(uint8 a, string calldata b) external returns (address) {
    StableOracle orac = new StableOracle(a, b);
    orac.transferOwnership(msg.sender);
    return address(orac);
  }

}

