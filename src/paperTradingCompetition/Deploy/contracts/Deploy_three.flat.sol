
/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(
                and(
                    iszero(iszero(denominator)),
                    or(iszero(x), eq(div(z, x), y))
                )
            ) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(
                and(
                    iszero(iszero(denominator)),
                    or(iszero(x), eq(div(z, x), y))
                )
            ) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >0.8.0;

library Printing {
    function append(string memory a, string memory b, string memory c, string memory d, string memory e) internal pure returns (string memory) {

    return string(abi.encodePacked(a, b, c,d, e));

}

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
            if (_i == 0) {
                return "0";
            }
            uint j = _i;
            uint len;
            while (j != 0) {
                len++;
                j /= 10;
            }
            bytes memory bstr = new bytes(len);
            uint k = len;
            while (_i != 0) {
                k = k-1;
                uint8 temp = (48 + uint8(_i - _i / 10 * 10));
                bytes1 b1 = bytes1(temp);
                bstr[k] = b1;
                _i /= 10;
            }
            return string(bstr);
        }

function makeString(bytes memory byteCode) internal pure returns(string memory stringData)
{
    uint256 blank = 0; //blank 32 byte value
    uint256 length = byteCode.length;

    uint cycles = byteCode.length / 0x20;
    uint requiredAlloc = length;

    if (length % 0x20 > 0) //optimise copying the final part of the bytes - to avoid looping with single byte writes
    {
        cycles++;
        requiredAlloc += 0x20; //expand memory to allow end blank, so we don't smack the next stack entry
    }

    stringData = new string(requiredAlloc);

    //copy data in 32 byte blocks
    assembly {
        let cycle := 0

        for
        {
            let mc := add(stringData, 0x20) //pointer into bytes we're writing to
            let cc := add(byteCode, 0x20)   //pointer to where we're reading from
        } lt(cycle, cycles) {
            mc := add(mc, 0x20)
            cc := add(cc, 0x20)
            cycle := add(cycle, 0x01)
        } {
            mstore(mc, mload(cc))
        }
    }

    //finally blank final bytes and shrink size (part of the optimisation to avoid looping adding blank bytes1)
    if (length % 0x20 > 0)
    {
        uint offsetStart = 0x20 + length;
        assembly
        {
            let mc := add(stringData, offsetStart)
            mstore(mc, mload(add(blank, 0x20)))
            //now shrink the memory back so the returned object is the correct size
            mstore(stringData, length)
        }
    }
}
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IChainLinkData {
    function latestRoundData()
            external
            view
            returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
            );
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;


interface IOraclesHub {
  function getRate(address[] memory, uint256) external view returns (uint256, uint256);
  function checkOracleSequence (address[] memory oracleAdresses) external view;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
////import "../interfaces/IOraclesHub.sol";
////import "../interfaces/IMainRegistry.sol";
////import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Abstract Sub-registry
  * @author Arcadia Finance
  * @notice Sub-Registries store pricing logic and basic information for tokens that can, or could at some point, be deposited in the vaults
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */ 
abstract contract SubRegistry is Ownable {
  using FixedPointMathLib for uint256;
  
  address public _mainRegistry;
  address public _oracleHub;
  address[] public assetsInSubRegistry;
  mapping (address => bool) public inSubRegistry;
  mapping (address => bool) public isAssetAddressWhiteListed;

  struct GetValueInput {
    address assetAddress;
    uint256 assetId;
    uint256 assetAmount;
    uint256 numeraire;
  }

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor (address mainRegistry, address oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //ToDo Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address, uint256) external view virtual returns (bool) {
    return false;
  }

  /**
   * @notice Removes an asset from the white-list
   * @param assetAddress The token address of the asset that needs to be removed from the white-list
   */
  function removeFromWhiteList(address assetAddress) external onlyOwner {
    require(inSubRegistry[assetAddress], 'Asset not known in Sub-Registry');
    isAssetAddressWhiteListed[assetAddress] = false;
  }

  /**
   * @notice Adds an asset to the white-list
   * @param assetAddress The token address of the asset that needs to be added to the white-list
   */
  function addToWhiteList(address assetAddress) external onlyOwner {
    require(inSubRegistry[assetAddress], 'Asset not known in Sub-Registry');
    isAssetAddressWhiteListed[assetAddress] = true;
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   */
  function getValue(GetValueInput memory) public view virtual returns (uint256, uint256) {
    
  }

}





/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: AGPL-3.0-only
pragma solidity >=0.8.6;

////import "../utils/Strings.sol";

////import "../../lib/solmate/src/tokens/ERC721.sol";

contract ERC721Mock is ERC721 {
    using Strings for uint256;

    string baseURI;
    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
    }


    function mint(address to, uint256 id) public virtual {
        _mint(to, id);
    }

    function setBaseUri(string calldata newBaseUri) external onlyOwner {
        baseURI = newBaseUri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory)
    {
        require(
            ownerOf[tokenId] != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory currentBaseURI = baseURI;
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
            : "";
    }
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
////import "./interfaces/IChainLinkData.sol";

////import {Printing} from "./utils/Printer.sol";
////import {FixedPointMathLib} from './utils/FixedPointMathLib.sol';

/** 
  * @title Oracle Hub
  * @author Arcadia Finance
  * @notice The Oracle Hub stores the adressesses and other necessary information of the Oracles
  * @dev No end-user should directly interact with the Main-registry, only the Main Registry, Sub-Registries or the contract owner
 */ 
contract OracleHub is Ownable {
  using FixedPointMathLib for uint256;

  struct OracleInformation {
    uint64 oracleUnit;
    uint8 baseAssetNumeraire;
    bool baseAssetIsNumeraire;
    string quoteAsset;
    string baseAsset;
    address oracleAddress;
    address quoteAssetAddress;
  }
  
  mapping (address => bool) public inOracleHub;
  mapping (address => OracleInformation) public oracleToOracleInformation;

  /**
   * @notice Constructor
   */
  constructor () {}

  /**
   * @notice Add a new oracle to the Oracle Hub
   * @param oracleInformation A Struct with information about the new Oracle
   * @dev It is not possible to overwrite the information of an existing Oracle in the Oracle Hub
   */
  function addOracle(OracleInformation calldata oracleInformation) external onlyOwner { //Need separate function to edit existing oracles?
    address oracleAddress = oracleInformation.oracleAddress;
    require(!inOracleHub[oracleAddress], 'Oracle already in oracle-hub');
    require(oracleInformation.oracleUnit <= 1000000000000000000, 'Oracle can have maximal 18 decimals');
    inOracleHub[oracleAddress] = true;
    oracleToOracleInformation[oracleAddress] = oracleInformation;
  }

  /**
   * @notice Checks if two input strings are identical, if so returns true
   * @param a The first string to be compared
   * @param b The second string to be compared
   * @return stringsMatch Boolean that returns true if both input strings are equal, and false if both strings are different
   */
  function compareStrings(string memory a, string memory b) internal pure returns (bool stringsMatch) {
      if(bytes(a).length != bytes(b).length) {
          return false;
      } else {
          stringsMatch = keccak256(bytes(a)) == keccak256(bytes(b));
      }
  }

  /**
   * @notice Checks if a series of oracles , if so returns true
   * @param oracleAdresses An array of addresses of oracle contracts
   * @dev Function will do nothing if all checks pass, but reverts if at least one check fails.
   *      The following checks are performed:
   *      The oracle-address must be previously added to the Oracle-Hub.
   *      The last oracle in the series must have USD as base-asset.
   *      The Base-asset of all oracles must be equal to the quote-asset of the next oracle (except for the last oracle in the series).
   */
  function checkOracleSequence (address[] memory oracleAdresses) external view {
    uint256 oracleAdressesLength = oracleAdresses.length;
    require(oracleAdressesLength <= 3, "Oracle seq. cant be longer than 3");
    for (uint256 i; i < oracleAdressesLength;) {
      require(inOracleHub[oracleAdresses[i]], "Unknown oracle");
      //Add test that in all other cases, the quote asset of next oracle matches base asset of previous oracle
      if (i > 0) {
        require(compareStrings(oracleToOracleInformation[oracleAdresses[i-1]].baseAsset, oracleToOracleInformation[oracleAdresses[i]].quoteAsset), "qAsset doesnt match with bAsset of prev oracle");
      }
      //Add test that base asset of last oracle is USD
      if (i == oracleAdressesLength-1) {
        require(compareStrings(oracleToOracleInformation[oracleAdresses[i]].baseAsset, "USD"), "Last oracle does not have USD as bAsset");
      }
      unchecked {++i;} 
    }

  }

  /**
   * @notice Returns the exchange rate of a certain asset, denominated in USD or in another Numeraire
   * @param oracleAdresses An array of addresses of oracle contracts
   * @param numeraire The Numeraire (base-asset) in which the exchange rate is ideally expressed
   * @return rateInUsd The exchange rate of the asset denominated in USD with 18 Decimals precision
   * @return rateInNumeraire The exchange rate of the asset denominated in a Numeraire different from USD with 18 Decimals precision
   * @dev The Function will loop over all oracles-addresses and find the total exchange rate of the asset by
   *      multiplying the intermediate exchangerates (max 3) with eachother. Exchange rates can be with any Decimals precision, but smaller than 18.
   *      All intermediate exchange rates are calculated with a precision of 18 decimals and rounded down.
   *      Todo: check precision when multiplying multiple small rates -> go to 27 decimals precision??
   *      The exchange rate of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset
   *      Function will overflow if any of the intermediate or the final exchange rate overflows
   *      Example of 3 oracles with R1 the first exchange rate with D1 decimals and R2 the second exchange rate with D2 decimals R3...
   *        First intermediate rate will overflow when R1 * 10**18 > MAXUINT256
   *        Second rate will overflow when R1 * R2 * 10**(18 - D1) > MAXUINT256
   *        Third and final exchange rate will overflow when R1 * R2 * R3 * 10**(18 - D1 - D2) > MAXUINT256
   */
  function getRate(address[] memory oracleAdresses, uint256 numeraire) public view returns (uint256, uint256) {

    //Scalar 1 with 18 decimals
    uint256 rate = FixedPointMathLib.WAD;
    int256 tempRate;

    uint256 oraclesLength = oracleAdresses.length;

    //taking into memory, saves 209 gas
    address oracleAddressAtIndex;
    for (uint256 i; i < oraclesLength;) {
      oracleAddressAtIndex = oracleAdresses[i];
      (, tempRate,,,) = IChainLinkData(oracleToOracleInformation[oracleAddressAtIndex].oracleAddress).latestRoundData();
      require(tempRate >= 0, "Negative oracle price");

      rate = rate.mulDivDown(uint256(tempRate), oracleToOracleInformation[oracleAddressAtIndex].oracleUnit);

      if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetIsNumeraire && oracleToOracleInformation[oracleAddressAtIndex].baseAssetNumeraire == 0) {
        //If rate is expressed in USD, break loop and return rate expressed in numeraire
        return (rate, 0);
      } else if (oracleToOracleInformation[oracleAddressAtIndex].baseAssetIsNumeraire && oracleToOracleInformation[oracleAddressAtIndex].baseAssetNumeraire == numeraire) {
        //If rate is expressed in numeraire, break loop and return rate expressed in numeraire
        return (0, rate);
      }
      unchecked {++i;}
    }
    revert('No oracle with USD or numeraire as bAsset');
  }

}





/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./AbstractSubRegistry.sol";

/** 
  * @title Sub-registry for ERC721 tokens for which a oracle exists for the floor price of the collection
  * @author Arcadia Finance
  * @notice The FloorERC721SubRegistry stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
  *         for the floor price of the collection
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721SubRegistry is SubRegistry {

  struct AssetInformation {
    uint256 idRangeStart;
    uint256 idRangeEnd;
    address assetAddress;
    address[] oracleAddresses;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor(address mainRegistry, address oracleHub) SubRegistry(mainRegistry, oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }
  
  /**
   * @notice Add a new asset to the FloorERC721SubRegistry, or overwrite an existing one
   * @param assetInformation A Struct with information about the asset 
   * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires
   * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
   *      or the list must have lenth 0. If the list has length zero, the credit ratings of the asset for all numeraires is
   *      is initiated as credit rating with index 0 by default (worst credit rating)
   * @dev The asset needs to be added/overwritten in the Main-Registry as well
   */ 
  function setAssetInformation(AssetInformation calldata assetInformation, uint256[] calldata assetCreditRatings) external onlyOwner {

    IOraclesHub(_oracleHub).checkOracleSequence(assetInformation.oracleAddresses);
    
    address assetAddress = assetInformation.assetAddress;
    //require(!inSubRegistry[assetAddress], 'Asset already known in Sub-Registry');
    if (!inSubRegistry[assetAddress]) {
      inSubRegistry[assetAddress] = true;
      assetsInSubRegistry.push(assetAddress);
    }
    assetToInformation[assetAddress] = assetInformation;
    isAssetAddressWhiteListed[assetAddress] = true;
    IMainRegistry(_mainRegistry).addAsset(assetAddress, assetCreditRatings);
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @param assetAddress The address of the asset
   * @param assetId The Id of the asset
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address assetAddress, uint256 assetId) external override view returns (bool) {
    if (isAssetAddressWhiteListed[assetAddress]) {
      if (isIdInRange(assetAddress, assetId)) {
        return true;
      }
    }

    return false;
  }

  /**
   * @notice Checks if the Id for a given token is in the range for which there exists a price feed
   * @param assetAddress The address of the asset
   * @param assetId The Id of the asset
   * @return A boolean, indicating if the Id of the given asset is whitelisted
   */
  function isIdInRange(address assetAddress, uint256 assetId) private view returns (bool) {
    if (assetId >= assetToInformation[assetAddress].idRangeStart && assetId <= assetToInformation[assetAddress].idRangeEnd) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset denominated in USD or
   *                      denominated in a given Numeraire different from USD
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   * @dev The value of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset.
   *      Only one of the two values can be different from 0.
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256 valueInUsd, uint256 valueInNumeraire) {
 
    (valueInUsd, valueInNumeraire) = IOraclesHub(_oracleHub).getRate(assetToInformation[getValueInput.assetAddress].oracleAddresses, getValueInput.numeraire);
  }
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./AbstractSubRegistry.sol";
////import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Sub-registry for Standard ERC20 tokens
  * @author Arcadia Finance
  * @notice The StandardERC20Registry stores pricing logic and basic information for ERC20 tokens for which a direct price feeds exists
  * @dev No end-user should directly interact with the Main-registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC20Registry is SubRegistry {
  using FixedPointMathLib for uint256;

  struct AssetInformation {
    uint64 assetUnit;
    address assetAddress;
    address[] oracleAddresses;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param mainRegistry The address of the Main-registry
   * @param oracleHub The address of the Oracle-Hub 
   */
  constructor (address mainRegistry, address oracleHub) SubRegistry(mainRegistry, oracleHub) {
    //owner = msg.sender;
    _mainRegistry = mainRegistry;
    _oracleHub = oracleHub; //Not the best place to store oraclehub address in sub-registries. Redundant + lot's of tx required of oraclehub is ever changes
  }

  /**
   * @notice Add a new asset to the StandardERC20Registry, or overwrite an existing one
   * @param assetInformation A Struct with information about the asset 
   * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires
   * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
   *  or the list must have lenth 0. If the list has length zero, the credit ratings of the asset for all numeraires is
   *  is initiated as credit rating with index 0 by default (worst credit rating)
   * @dev The asset needs to be added/overwritten in the Main-Registry as well
   */
  function setAssetInformation(AssetInformation calldata assetInformation, uint256[] calldata assetCreditRatings) external onlyOwner {
    
    IOraclesHub(_oracleHub).checkOracleSequence(assetInformation.oracleAddresses);

    address assetAddress = assetInformation.assetAddress;
    require(assetInformation.assetUnit <= 10**18, 'Asset can have maximal 18 decimals');
    if (!inSubRegistry[assetAddress]) {
      inSubRegistry[assetAddress] = true;
      assetsInSubRegistry.push(assetAddress);
    }
    assetToInformation[assetAddress] = assetInformation;
    isAssetAddressWhiteListed[assetAddress] = true;
    IMainRegistry(_mainRegistry).addAsset(assetAddress, assetCreditRatings);
  }

  /**
   * @notice Returns the information that is stored in the Sub-registry for a given asset
   * @dev struct is not taken into memory; saves 6613 gas
   * @param asset The Token address of the asset
   * @return assetDecimals The number of decimals of the asset
   * @return assetAddress The Token address of the asset
   * @return oracleAddresses The list of addresses of the oracles to get the exchange rate of the asset in USD
   */
  function getAssetInformation(address asset) public view returns (uint64, address, address[] memory) {
    return (assetToInformation[asset].assetUnit, assetToInformation[asset].assetAddress, assetToInformation[asset].oracleAddresses);
  }

  /**
   * @notice Checks for a token address and the corresponding Id if it is white-listed
   * @param assetAddress The address of the asset
   * @dev For each token address, a corresponding id at the same index should be present,
   *      for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @return A boolean, indicating if the asset passed as input is whitelisted
   */
  function isWhiteListed(address assetAddress, uint256) external override view returns (bool) {
    if (isAssetAddressWhiteListed[assetAddress]) {
      return true;
    }

    return false;
  }

  /**
   * @notice Returns the value of a certain asset, denominated in USD or in another Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset denominated in USD or
   *  denominated in a given Numeraire different from USD
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   * @dev The value of an asset will be denominated in a Numeraire different from USD if and only if
   *      the given Numeraire is different from USD and one of the intermediate oracles to price the asset has
   *      the given numeraire as base-asset.
   *      Only one of the two values can be different from 0.
   *      Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256, uint256) {
    uint256 value;
    uint256 rateInUsd;
    uint256 rateInNumeraire;

    //Will return empty struct when asset is not first added to subregisrty -> still return a value without error
    //In reality however call will always pass via mainregistry, that already does the check
    //ToDo

    (rateInUsd, rateInNumeraire) = IOraclesHub(_oracleHub).getRate(assetToInformation[getValueInput.assetAddress].oracleAddresses, getValueInput.numeraire);

    if (rateInNumeraire > 0) {
      value = (getValueInput.assetAmount).mulDivDown(rateInNumeraire, assetToInformation[getValueInput.assetAddress].assetUnit);
      return (0, value);
    } else {
      value = (getValueInput.assetAmount).mulDivDown(rateInUsd, assetToInformation[getValueInput.assetAddress].assetUnit);
      return (value, 0);
    }
        
  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.8.0;

////import "../mockups/ERC721SolmateMock.sol";

contract ERC721PaperTrading is ERC721Mock {

  address private tokenShop;

  /**
   * @dev Throws if called by any address other than the tokenshop
   *  only added for the paper trading competition
   */
  modifier onlyTokenShop() {
    require(msg.sender == tokenShop, "Not tokenshop");
    _;
  }

  constructor(string memory name, string memory symbol, address _tokenShop) ERC721Mock(name, symbol) {
    tokenShop =_tokenShop;
  }

  function mint(address to, uint256 id) public override onlyTokenShop {
    _mint(to, id);
  }


  function burn(uint256 id) public {
      require(msg.sender == ownerOf[id], "You are not the owner");
      _burn(id);
  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.8.0;

////import "../mockups/ERC20SolmateMock.sol";

contract ERC20PaperTrading is ERC20Mock {

  address private tokenShop;

  /**
   * @dev Throws if called by any address other than the tokenshop
   *  only added for the paper trading competition
   */
  modifier onlyTokenShop() {
    require(msg.sender == tokenShop, "Not tokenshop");
    _;
  }

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address _tokenShop) ERC20Mock(name, symbol, _decimalsInput) {
    tokenShop =_tokenShop;
  }

  function mint(address to, uint256 amount) public override onlyTokenShop {
    _mint(to, amount);
  }

}

/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_three.sol
*/

////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >0.8.10;

////import "../../ERC20PaperTrading.sol";
////import "../../ERC721PaperTrading.sol";
////import "../../../AssetRegistry/StandardERC20SubRegistry.sol";
////import "../../../AssetRegistry/FloorERC721SubRegistry.sol";
////import "../../../OracleHub.sol";

contract DeployContractsThree  {
  

  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  
  function deployERC20(string calldata a, string calldata b, uint8 c, address d) external returns (address) {
    ERC20PaperTrading erc20 = new ERC20PaperTrading(a, b, c, d);
    return address(erc20);
  }

  function deployERC721(string calldata a, string calldata b, address c) external returns (address) {
    ERC721PaperTrading erc721 = new ERC721PaperTrading(a, b, c);
    return address(erc721);
  }

  function deployOracHub() external returns (address) {
    OracleHub orachub = new OracleHub();
    orachub.transferOwnership(msg.sender);
    return address(orachub);
  }

  function deployERC20SubReg(address a, address b) external returns (address) {
    StandardERC20Registry erc20Reg = new StandardERC20Registry(a, b);
    erc20Reg.transferOwnership(msg.sender);
    return address(erc20Reg);
  }

  function deployERC721SubReg(address a, address b) external returns (address) {
    FloorERC721SubRegistry erc721Reg = new FloorERC721SubRegistry(a, b);
    erc721Reg.transferOwnership(msg.sender);
    return address(erc721Reg);
  }
  
}

