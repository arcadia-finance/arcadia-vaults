
/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC1155 {
  function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
  }



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC721 {
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function ownerOf(uint256 tokenId) external view returns (address owner);
  function transferFrom(address from, address to, uint256 id) external;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC20 {
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
  function transfer(address to, uint256 amount) external returns (bool);
  function balanceOf(address) external view returns (uint256);
  function mint(address to, uint256 amount) external;
  function burn(uint256 amount) external;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../../interfaces/IFactory.sol";

interface IFactoryPaperTrading is IFactory {
  function getVaultAddress(uint256 id) external view returns(address);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../../interfaces/IERC1155.sol";

interface IERC1155PaperTrading is IERC1155 {
  function mint(address to, uint256 id, uint256 amount) external;
  function burn(uint256 id, uint256 amount) external;
  }



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../../interfaces/IERC721.sol";

interface IERC721PaperTrading is IERC721 {
  function mint(address to, uint256 id) external;
  function burn(uint256 id) external;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../../interfaces/IERC20.sol";

interface IERC20PaperTrading is IERC20 {

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IStable {
  function safeBurn(address from, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
////import "./interfaces/IERC20PaperTrading.sol";
////import "./interfaces/IERC721PaperTrading.sol";
////import "./interfaces/IERC1155PaperTrading.sol";
////import "./interfaces/IVaultPaperTrading.sol";
////import "./interfaces/IFactoryPaperTrading.sol";
////import "./../interfaces/IMainRegistry.sol";

////import {Printing} from "./../utils/Printer.sol";
////import {FixedPointMathLib} from './../utils/FixedPointMathLib.sol';

/** 
  * @title Token Shop
  * @author Arcadia Finance
  * @notice Mocked Exchange for the Arcadia Paper Trading Game
  * @dev For testnet purposes only
 */ 

contract TokenShop is Ownable {
  using FixedPointMathLib for uint256;

  address public factory;
  address public mainRegistry;

  struct SwapInput {
    address[] tokensIn;
    uint256[] idsIn;
    uint256[] amountsIn;
    uint256[] assetTypesIn;
    address[] tokensOut;
    uint256[] idsOut;
    uint256[] amountsOut;
    uint256[] assetTypesOut;
    uint256 vaultId;
  }

  constructor (address _mainRegistry) {
    mainRegistry = _mainRegistry;
  }

  /**
   * @dev Sets the new Factory address
   * @param _factory The address of the Factory
   */
  function setFactory(address _factory) public {
    factory = _factory;
  }

  function swapExactTokensForTokens(SwapInput calldata swapInput) external {
    require(msg.sender == IERC721(factory).ownerOf(swapInput.vaultId), "You are not the owner");
    address vault = IFactoryPaperTrading(factory).getVaultAddress(swapInput.vaultId);
    (,,,,,uint8 numeraire) = IVaultPaperTrading(vault).debt();

    uint256 totalValueIn = IMainRegistry(mainRegistry).getTotalValue(swapInput.tokensIn, swapInput.idsIn, swapInput.amountsIn, numeraire);
    uint256 totalValueOut = IMainRegistry(mainRegistry).getTotalValue(swapInput.tokensOut, swapInput.idsOut, swapInput.amountsOut, numeraire);
    require (totalValueIn >= totalValueOut, "Not enough funds");

    IVaultPaperTrading(vault).withdraw(swapInput.tokensIn, swapInput.idsIn, swapInput.amountsIn, swapInput.assetTypesIn);
    _burn(swapInput.tokensIn, swapInput.idsIn, swapInput.amountsIn, swapInput.assetTypesIn);
    _mint(swapInput.tokensOut, swapInput.idsOut, swapInput.amountsOut, swapInput.assetTypesOut);
    IVaultPaperTrading(vault).deposit(swapInput.tokensOut, swapInput.idsOut, swapInput.amountsOut, swapInput.assetTypesOut);

    if (totalValueIn > totalValueOut) {
      uint256 amountNumeraire = totalValueIn - totalValueOut;
      address stable = IVaultPaperTrading(vault)._stable();
      _mintERC20(stable, amountNumeraire);

      address[] memory stableArr = new address[](1);
      uint256[] memory stableIdArr = new uint256[](1);
      uint256[] memory stableAmountArr = new uint256[](1);
      uint256[] memory stableTypeArr = new uint256[](1);

      stableArr[0] = stable;
      stableIdArr[0] = 0; //can delete
      stableAmountArr[0] = amountNumeraire;
      stableTypeArr[0] = 0; //can delete

      IVaultPaperTrading(vault).deposit(stableArr, stableIdArr, stableAmountArr, stableTypeArr);
    }

  }

  function _mint(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) internal {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    
    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _mintERC20(assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _mintERC721(assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _mintERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  function _burn(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) internal {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    
    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _burnERC20(assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _burnERC721(assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _burnERC1155(assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  function _mintERC20(address tokenAddress, uint256 tokenAmount) internal {
    IERC20PaperTrading(tokenAddress).mint(address(this), tokenAmount);
  }

  function _mintERC721(address tokenAddress, uint256 tokenId) internal {
    IERC721PaperTrading(tokenAddress).mint(address(this), tokenId);
  }

  function _mintERC1155(address tokenAddress, uint256 tokenId, uint256 tokenAmount) internal {
    IERC1155PaperTrading(tokenAddress).mint(address(this), tokenId, tokenAmount);
  }

  function _burnERC20(address tokenAddress, uint256 tokenAmount) internal {
    IERC20PaperTrading(tokenAddress).burn(tokenAmount);
  }

  function _burnERC721(address tokenAddress, uint256 tokenId) internal {
    IERC721PaperTrading(tokenAddress).burn(tokenId);
  }

  function _burnERC1155(address tokenAddress, uint256 tokenId, uint256 tokenAmount) internal {
    IERC1155PaperTrading(tokenAddress).burn(tokenId, tokenAmount);
  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./interfaces/IFactory.sol";
////import "./interfaces/IMainRegistry.sol";
////import "./interfaces/IStable.sol";
////import "./interfaces/IVault.sol";
////import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract Liquidator is Ownable {

  address public factoryAddress;
  uint8 public numeraireOfDebt;
  address public registryAddress;
  address public stable;
  address public reserveFund;

  uint256 constant public hourlyBlocks = 300;
  uint256 public auctionDuration = 6; //hours

  claimRatios public claimRatio;

  struct claimRatios {
    uint64 protocol;
    uint64 originalOwner;
    uint64 liquidator;
    uint64 reserveFund;
  }

  struct auctionInformation {
    uint128 openDebt;
    uint128 startBlock;
    uint8 liqThres;
    uint128 stablePaid;
    address liquidator;
    address originalOwner;
  }

  mapping (address => mapping (uint256 => auctionInformation)) public auctionInfo;
  mapping (address => uint256) public claimableBitmap;

  constructor(address newFactory, address newRegAddr, address stableAddr) {
    factoryAddress = newFactory;
    numeraireOfDebt = 0;
    registryAddress = newRegAddr;
    stable = stableAddr;
    claimRatio = claimRatios({protocol: 20, originalOwner: 60, liquidator: 10, reserveFund: 10});
  }

  modifier elevated() {
    require(IFactory(factoryAddress).isVault(msg.sender), "This can only be called by a vault");
    _;
  }

  function setFactory(address newFactory) external onlyOwner {
    factoryAddress = newFactory;
  }

  //function startAuction() modifier = only by vault
  //  sets time start to now()
  //  stores the liquidator
  // 

  function startAuction(address vaultAddress, uint256 life, address liquidator, address originalOwner, uint128 openDebt, uint8 liqThres) public elevated returns (bool) {

    require(auctionInfo[vaultAddress][life].startBlock == 0, "Liquidation already ongoing");

    auctionInfo[vaultAddress][life].startBlock = uint128(block.number);
    auctionInfo[vaultAddress][life].liquidator = liquidator;
    auctionInfo[vaultAddress][life].originalOwner = originalOwner;
    auctionInfo[vaultAddress][life].openDebt = openDebt;
    auctionInfo[vaultAddress][life].liqThres = liqThres;

    return true;
  }

  //function getPrice(assets) view
  // gets the price of assets, equals to oracle price + factor depending on time
   /** 
    @notice Function to check what the value of the items in the vault is.
    @dev 
    @param assetAddresses the vaultAddress 
    @param assetIds the vaultAddress 
    @param assetAmounts the vaultAddress 
  */
  function getPriceOfAssets(address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) public view returns (uint256) {
    uint256 totalValue = IMainRegistry(registryAddress).getTotalValue(assetAddresses, assetIds, assetAmounts, numeraireOfDebt);
    return totalValue;
  }

  // gets the price of assets, equals to oracle price + factor depending on time
   /** 
    @notice Function to buy only a certain asset of a vault in the liquidation process
    @dev 
    @param assetAddresses the vaultAddress 
    @param assetIds the vaultAddress 
    @param assetAmounts the vaultAddress 
  */
  function buyPart(address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) public {

  }
   /** 
    @notice Function to check what the current price of the vault being auctioned of is.
    @dev 
    @param vaultAddress the vaultAddress 
  */
  function getPriceOfVault(address vaultAddress, uint256 life) public view returns (uint256, bool) {
    // it's cheaper to look up the struct in the mapping than to take it into memory
    //auctionInformation memory auction = auctionInfo[vaultAddress][life];
    uint256 startPrice = auctionInfo[vaultAddress][life].openDebt * auctionInfo[vaultAddress][life].liqThres / 100;
    uint256 surplusPrice = auctionInfo[vaultAddress][life].openDebt * (auctionInfo[vaultAddress][life].liqThres-100) / 100;
    uint256 priceDecrease = surplusPrice * (block.number - auctionInfo[vaultAddress][life].startBlock) / (hourlyBlocks * auctionDuration);

    if (startPrice < priceDecrease) {
      return (0, false);
    }

    uint256 totalPrice = startPrice - priceDecrease; 
    bool forSale = block.number - auctionInfo[vaultAddress][life].startBlock <= hourlyBlocks * auctionDuration ? true : false;
    return (totalPrice, forSale);
  }
    /** 
    @notice Function a user calls to buy the vault during the auction process. This ends the auction process
    @dev 
    @param vaultAddress the vaultAddress of the vault the user want to buy.
  */

  function buyVault(address vaultAddress, uint256 life) public {
    // it's 3683 gas cheaper to look up the struct 6x in the mapping than to take it into memory
    (uint256 priceOfVault, bool forSale) = getPriceOfVault(vaultAddress, life);

    require(forSale, "Too much time has passed: this vault is not for sale");
    require(auctionInfo[vaultAddress][life].stablePaid < auctionInfo[vaultAddress][life].openDebt, "This vaults debt has already been paid in full!");

    uint256 surplus = priceOfVault - auctionInfo[vaultAddress][life].openDebt;

    require(IStable(stable).safeBurn(msg.sender, auctionInfo[vaultAddress][life].openDebt), "Cannot burn sufficient stable debt");
    require(IStable(stable).transferFrom(msg.sender, address(this), surplus), "Surplus transfer failed");

    auctionInfo[vaultAddress][life].stablePaid = uint128(priceOfVault);
    
    //TODO: fetch vault id.
    IFactory(factoryAddress).safeTransferFrom(address(this), msg.sender, IFactory(factoryAddress).vaultIndex(vaultAddress));
  }
    /** 
    @notice Function a a user can call to check who is eligbile to claim what from an auction vault.
    @dev 
    @param auction the auction
    @param vaultAddress the vaultAddress of the vault the user want to buy.
    @param life the lifeIndex of vault, the keeper wants to claim their reward from
  */
  function claimable(auctionInformation memory auction, address vaultAddress, uint256 life) public view returns (uint256[] memory, address[] memory) {
    claimRatios memory ratios = claimRatio;
    uint256[] memory claimables = new uint256[](4);
    address[] memory claimableBy = new address[](4);
    uint256 claimableBitmapMem = claimableBitmap[vaultAddress];

    uint256 surplus = auction.stablePaid - auction.openDebt;

    claimables[0] = claimableBitmapMem & (1 << 4*life + 0) == 0 ? surplus * ratios.protocol / 100: 0;
    claimables[1] = claimableBitmapMem & (1 << 4*life + 1) == 0 ? surplus * ratios.originalOwner / 100: 0;
    claimables[2] = claimableBitmapMem & (1 << 4*life + 2) == 0 ? surplus * ratios.liquidator / 100: 0;
    claimables[3] = claimableBitmapMem & (1 << 4*life + 3) == 0 ? surplus * ratios.reserveFund / 100: 0;

    claimableBy[0] = address(this);
    claimableBy[1] = auction.originalOwner;
    claimableBy[2] = auction.liquidator;
    claimableBy[3] = reserveFund;

    return (claimables, claimableBy);
  }
    /** 
    @notice Function a eligeble claimer can call to claim the proceeds of the vault they are entitled to.
    @dev 
    @param vaultAddresses vaultAddresses the caller want to claim the proceeds from.
    */
  function claimProceeds(address[] calldata vaultAddresses, uint256[] calldata lives) public {
    uint256 len = vaultAddresses.length;
    require(len == lives.length, "Arrays must be of same length");

    uint256 totalClaimable;
    uint256 claimableBitmapMem;

    uint256[] memory claimables;
    address[] memory claimableBy;
    for (uint256 i; i < len;) {
      address vaultAddress = vaultAddresses[i];
      uint256 life = lives[i];
      auctionInformation memory auction = auctionInfo[vaultAddress][life];
      (claimables, claimableBy) = claimable(auction, vaultAddress, life);
      claimableBitmapMem = claimableBitmap[vaultAddress];

      if (msg.sender == claimableBy[0]) {
        totalClaimable += claimables[0];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 0));
      }
      if (msg.sender == claimableBy[1]) {
        totalClaimable += claimables[1];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 1));
      }
      if (msg.sender == claimableBy[2]) {
        totalClaimable += claimables[2];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 2));
      }
      if (msg.sender == claimableBy[3]) {
        totalClaimable += claimables[3];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 3));
      }

      claimableBitmap[vaultAddress] = claimableBitmapMem;

      unchecked {++i;}
    }

    require(IStable(stable).transferFrom(address(this), msg.sender, totalClaimable));
  }

  //function buy(assets, amounts, ids) payable
  //  fetches price of first provided
  //  if buy-price is >= open debt, close auction & take fees (how?)
  //  (if all assets are bought, transfer vault)
  //  (for purchase that ends auction, give discount?)


}




/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
////import "../interfaces/IChainLinkData.sol";
////import "../interfaces/IOraclesHub.sol";
////import "../interfaces/IFactory.sol";

////import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

interface ISubRegistry {
  function isAssetAddressWhiteListed(address) external view returns (bool);
  struct GetValueInput {
    address assetAddress;
    uint256 assetId;
    uint256 assetAmount;
    uint256 numeraire;
  }
  
  function isWhiteListed(address, uint256) external view returns (bool);
  function getValue(GetValueInput memory) external view returns (uint256, uint256);
}

/** 
  * @title Main Asset registry
  * @author Arcadia Finance
  * @notice The Main-registry stores basic information for each token that can, or could at some point, be deposited in the vaults
  * @dev No end-user should directly interact with the Main-registry, only vaults, Sub-Registries or the contract owner
 */ 
contract MainRegistry is Ownable {
  using FixedPointMathLib for uint256;

  bool public assetsUpdatable = true;

  uint256 public constant CREDIT_RATING_CATOGERIES = 10;

  address[] private subRegistries;
  address[] public assetsInMainRegistry;

  mapping (address => bool) public inMainRegistry;
  mapping (address => bool) public isSubRegistry;
  mapping (address => address) public assetToSubRegistry;

  address public factoryAddress;

  struct NumeraireInformation {
    uint64 numeraireToUsdOracleUnit;
    uint64 numeraireUnit;
    address assetAddress;
    address numeraireToUsdOracle;
    address stableAddress;
    string numeraireLabel;
  }

  uint256 public numeraireCounter;
  mapping (uint256 => NumeraireInformation) public numeraireToInformation;

  mapping (address => mapping (uint256 => uint256)) public assetToNumeraireToCreditRating;

  /**
   * @dev Only Sub-registries can call functions marked by this modifier.
   **/
  modifier onlySubRegistry {
    require(isSubRegistry[msg.sender], 'Caller is not a sub-registry.');
    _;
  }

  /**
   * @notice The Main Registry must always be initialised with at least one Numeraire: USD
   * @dev If the Numeraire has no native token, numeraireDecimals should be set to 0 and assetAddress to the null address
   * @param _numeraireInformation A Struct with information about the Numeraire USD
   */
  constructor (NumeraireInformation memory _numeraireInformation) {
    //Main registry must be initialised with usd
    numeraireToInformation[numeraireCounter] = _numeraireInformation;
    unchecked {++numeraireCounter;}
  }

  /**
   * @notice Sets the new Factory address
   * @dev The factory can only be set on the Main Registry AFTER the Main registry is set in the Factory.
   *  This ensures that the allowed Numeraires and corresponding stable contracts in both are equal.
   * @param _factoryAddress The address of the Factory
   */
  function setFactory(address _factoryAddress) external onlyOwner {
    require(IFactory(_factoryAddress).getCurrentRegistry() == address(this), "MR_AA: MR not set in factory");
    factoryAddress = _factoryAddress;

    uint256 factoryNumeraireCounter = IFactory(_factoryAddress).numeraireCounter();
    if (numeraireCounter > factoryNumeraireCounter) {
      for (uint256 i = factoryNumeraireCounter; i < numeraireCounter;) {
        IFactory(factoryAddress).addNumeraire(i, numeraireToInformation[i].stableAddress);
        unchecked {++i;}
      }
    }
  }

  /**
   * @notice Checks for a list of tokens and a list of corresponding IDs if all tokens are white-listed
   * @param _assetAddresses The list of token addresses that needs to be checked 
   * @param _assetIds The list of corresponding token Ids that needs to be checked
   * @dev For each token address, a corresponding id at the same index should be present,
   *  for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @return A boolean, indicating of all assets passed as input are whitelisted
   */
  function batchIsWhiteListed(
    address[] calldata _assetAddresses, 
    uint256[] calldata _assetIds
  ) public view returns (bool) {

    //Check if all ERC721 tokens are whitelisted
    uint256 addressesLength = _assetAddresses.length;
    require(addressesLength == _assetIds.length, "LENGTH_MISMATCH");

    address assetAddress;
    for (uint256 i; i < addressesLength;) {
      assetAddress = _assetAddresses[i];
      if (!inMainRegistry[assetAddress]) {
        return false;
      } else if (!ISubRegistry(assetToSubRegistry[assetAddress]).isWhiteListed(assetAddress, _assetIds[i])) {
        return false;
      }
      unchecked {++i;}
    }

    return true;

  }

  /**
   * @notice returns a list of all white-listed token addresses
   * @dev Function is not gas-optimsed and not intended to be called by other smart contracts
   * @return A list of all white listed token Adresses
   */
  function getWhiteList() external view returns (address[] memory) {
    uint256 maxLength = assetsInMainRegistry.length;
    address[] memory whiteList = new address[](maxLength);

    uint256 counter = 0;
    for (uint256 i; i < maxLength;) {
      address assetAddress = assetsInMainRegistry[i];
      if (ISubRegistry(assetToSubRegistry[assetAddress]).isAssetAddressWhiteListed(assetAddress)) {
        whiteList[counter] = assetAddress;
        unchecked {++counter;}
      }
      unchecked {++i;}
    }

    return whiteList;
  }

  /**
   * @notice Add a Sub-registry Address to the list of Sub-Registries
   * @param subAssetRegistryAddress Address of the Sub-Registry
   */
  function addSubRegistry(address subAssetRegistryAddress) external onlyOwner {
    require(!isSubRegistry[subAssetRegistryAddress], 'Sub-Registry already exists');
    isSubRegistry[subAssetRegistryAddress] = true;
    subRegistries.push(subAssetRegistryAddress);
  }

  /**
   * @notice Add a new asset to the Main Registry, or overwrite an existing one (if assetsUpdatable is True)
   * @param assetAddress The address of the asset
   * @param assetCreditRatings The List of Credit Rating Categories for the asset for the different Numeraires
   * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
   *  or the list must have lenth 0. If the list has length zero, the credit ratings of the asset for all numeraires is
   *  is initiated as credit rating with index 0 by default (worst credit rating).
   *  Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
   *  Category from 1 to 10 will be used to label groups of assets with similart risk profiles
   *  (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
   */
  function addAsset(address assetAddress, uint256[] memory assetCreditRatings) external onlySubRegistry {
    if (inMainRegistry[assetAddress]) {
      require(assetsUpdatable, 'MR_AA: already known');
    } else {
      inMainRegistry[assetAddress] = true;
      assetsInMainRegistry.push(assetAddress);
    }
    assetToSubRegistry[assetAddress] = msg.sender;

    uint256 assetCreditRatingsLength = assetCreditRatings.length;
    require(assetCreditRatingsLength == numeraireCounter || assetCreditRatingsLength == 0, 'MR_AA: LENGTH_MISMATCH');
    for (uint256 i; i < assetCreditRatingsLength;) {
      require(assetCreditRatings[i] < CREDIT_RATING_CATOGERIES, "MR_AA: non-existing");
      assetToNumeraireToCreditRating[assetAddress][i] = assetCreditRatings[i];
      unchecked {++i;}
    }
  }

  /**
   * @notice Change the Credit Rating Category for one or more assets for one or more numeraires
   * @param assets The List of addresses of the assets
   * @param numeraires The corresponding List of Numeraires
   * @param newCreditRating The corresponding List of new Credit Ratings
   * @dev The function loops over all indexes, and changes for each index the Credit Rating Category of the combination of asset and numeraire.
   *  In case multiple numeraires for the same assets need to be changed, the address must be repeated in the assets.
   *  Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
   *  Category from 1 to 10 will be used to label groups of assets with similart risk profiles
   *  (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
   */
  function batchSetCreditRating(address[] calldata assets, uint256[] calldata numeraires, uint256[] calldata newCreditRating) external onlyOwner {
    uint256 assetsLength = assets.length;
    require(assetsLength == numeraires.length && assetsLength == newCreditRating.length, "MR_BSCR: LENGTH_MISMATCH");

    for (uint256 i; i < assetsLength;) {
      require(newCreditRating[i] < CREDIT_RATING_CATOGERIES, "MR_BSCR: non-existing creditRat");
      assetToNumeraireToCreditRating[assets[i]][numeraires[i]] = newCreditRating[i];
      unchecked {++i;}
    }
  }

  /**
   * @notice Disables the updatability of assets. In the disabled states, asset properties become immutable
   **/
  function setAssetsToNonUpdatable() external onlyOwner {
    assetsUpdatable = false;
  }

  /**
   * @notice Add a new numeraire to the Main Registry, or overwrite an existing one
   * @param numeraireInformation A Struct with information about the Numeraire
   * @param assetCreditRatings The List of the Credit Rating Categories of the numeraire, for all the different assets in the Main registry
   * @dev The list of Credit Rating Categories should or be as long as the number of assets added to the Main Registry,
   *  or the list must have lenth 0. If the list has length zero, the credit ratings of the numeraire for all assets is
   *  is initiated as credit rating with index 0 by default (worst credit rating).
   *  Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets.
   *  Category from 1 to 10 will be used to label groups of assets with similart risk profiles
   *  (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
   *  ToDo: Add tests that existing numeraire cannot be entered second time?
   *  ToDo: check if assetCreditRating can be put in a struct
   */
  function addNumeraire(NumeraireInformation calldata numeraireInformation, uint256[] calldata assetCreditRatings) external onlyOwner {
    numeraireToInformation[numeraireCounter] = numeraireInformation;

    uint256 assetCreditRatingsLength = assetCreditRatings.length;
    require(assetCreditRatingsLength == assetsInMainRegistry.length || assetCreditRatingsLength == 0, 'MR_AN: lenght');
    for (uint256 i; i < assetCreditRatingsLength;) {
      require(assetCreditRatings[i] < CREDIT_RATING_CATOGERIES, "MR_AN: non existing credRat");
      assetToNumeraireToCreditRating[assetsInMainRegistry[i]][numeraireCounter] = assetCreditRatings[i];
      unchecked {++i;}
    }

    if (factoryAddress != address(0)) {
      IFactory(factoryAddress).addNumeraire(numeraireCounter, numeraireInformation.stableAddress);
    }
    unchecked {++numeraireCounter;}
  }

  /**
   * @notice Calculate the total value of a list of assets denominated in a given Numeraire
   * @param _assetAddresses The List of token addresses of the assets
   * @param _assetIds The list of corresponding token Ids that needs to be checked
   * @dev For each token address, a corresponding id at the same index should be present,
   *  for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
   * @param numeraire An identifier (uint256) of the Numeraire
   * @return valueInNumeraire The total value of the list of assets denominated in Numeraire
   * @dev Todo: Not yet tested for Over-and underflow
  *       ToDo: value sum unchecked. Cannot overflow on 1e18 decimals
   */
  function getTotalValue(
                        address[] calldata _assetAddresses, 
                        uint256[] calldata _assetIds,
                        uint256[] calldata _assetAmounts,
                        uint256 numeraire
                      ) public view returns (uint256 valueInNumeraire) {
    uint256 valueInUsd;

    require(numeraire <= numeraireCounter - 1, "MR_GTV: Unknown Numeraire");

    uint256 assetAddressesLength = _assetAddresses.length;
    require(assetAddressesLength == _assetIds.length && assetAddressesLength == _assetAmounts.length, "MR_GTV: LENGTH_MISMATCH");
    ISubRegistry.GetValueInput memory getValueInput;
    getValueInput.numeraire = numeraire;

    for (uint256 i; i < assetAddressesLength;) {
      address assetAddress = _assetAddresses[i];
      require(inMainRegistry[assetAddress], "MR_GTV: Unknown asset");

      getValueInput.assetAddress = assetAddress;
      getValueInput.assetId = _assetIds[i];
      getValueInput.assetAmount = _assetAmounts[i];

      if (assetAddress == numeraireToInformation[numeraire].assetAddress) { //Should only be allowed if the numeraire is ETH, not for stablecoins or wrapped tokens
        valueInNumeraire = valueInNumeraire + _assetAmounts[i].mulDivDown(FixedPointMathLib.WAD, numeraireToInformation[numeraire].numeraireUnit); //_assetAmounts must be a with 18 decimals precision
      } else {
          //Calculate value of the next asset and add it to the total value of the vault
          (uint256 tempValueInUsd, uint256 tempValueInNumeraire) = ISubRegistry(assetToSubRegistry[assetAddress]).getValue(getValueInput);
          valueInUsd = valueInUsd + tempValueInUsd;
          valueInNumeraire = valueInNumeraire + tempValueInNumeraire;
      }
      unchecked {++i;}
    }
    if (numeraire == 0) { //Check if numeraire is USD
      return valueInUsd;
    } else if (valueInUsd > 0) {
      //Get the Numeraire-USD rate
      (,int256 rate,,,) = IChainLinkData(numeraireToInformation[numeraire].numeraireToUsdOracle).latestRoundData();
      //Add valueInUsd to valueInNumeraire, to check if conversion from int to uint can always be done
      valueInNumeraire = valueInNumeraire + valueInUsd.mulDivDown(numeraireToInformation[numeraire].numeraireToUsdOracleUnit, uint256(rate));
    }

  }

  /**
   * @notice Calculate the value per asset of a list of assets denominated in a given Numeraire
   * @param _assetAddresses The List of token addresses of the assets
   * @param _assetIds The list of corresponding token Ids that needs to be checked
   * @dev For each token address, a corresponding id at the same index should be present,
   *      for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
   * @param numeraire An identifier (uint256) of the Numeraire
   * @return valuesPerAsset sThe list of values per assets denominated in Numeraire
   * @dev Todo: Not yet tested for Over-and underflow
   */
  function getListOfValuesPerAsset(
    address[] calldata _assetAddresses, 
    uint256[] calldata _assetIds,
    uint256[] calldata _assetAmounts,
    uint256 numeraire
  ) public view returns (uint256[] memory valuesPerAsset) {
    
    valuesPerAsset = new uint256[](_assetAddresses.length);

    require(numeraire <= numeraireCounter - 1, "MR_GLV: Unknown Numeraire");

    uint256 assetAddressesLength = _assetAddresses.length;
    require(assetAddressesLength == _assetIds.length && assetAddressesLength == _assetAmounts.length, "MR_GLV: LENGTH_MISMATCH");
    ISubRegistry.GetValueInput memory getValueInput;
    getValueInput.numeraire = numeraire;

    int256 rateNumeraireToUsd;

    for (uint256 i; i < assetAddressesLength;) {
      address assetAddress = _assetAddresses[i];
      require(inMainRegistry[assetAddress], "MR_GLV: Unknown asset");

      getValueInput.assetAddress = assetAddress;
      getValueInput.assetId = _assetIds[i];
      getValueInput.assetAmount = _assetAmounts[i];

      if (assetAddress == numeraireToInformation[numeraire].assetAddress) { //Should only be allowed if the numeraire is ETH, not for stablecoins or wrapped tokens
        valuesPerAsset[i] = _assetAmounts[i].mulDivDown(FixedPointMathLib.WAD, numeraireToInformation[numeraire].numeraireUnit); //_assetAmounts must be a with 18 decimals precision
      } else {
        //Calculate value of the next asset and add it to the total value of the vault
        (uint256 valueInUsd, uint256 valueInNumeraire) = ISubRegistry(assetToSubRegistry[assetAddress]).getValue(getValueInput);
        if (numeraire == 0) { //Check if numeraire is USD
          valuesPerAsset[i] = valueInUsd;
        } else if (valueInNumeraire > 0) {
            valuesPerAsset[i] = valueInNumeraire;
        } else {
          //Check if the Numeraire-USD rate is already fetched
          if (rateNumeraireToUsd == 0) {
            //Get the Numeraire-USD rate ToDo: Ask via the OracleHub?
            (,rateNumeraireToUsd,,,) = IChainLinkData(numeraireToInformation[numeraire].numeraireToUsdOracle).latestRoundData();  
          }
          valuesPerAsset[i] = valueInUsd.mulDivDown(numeraireToInformation[numeraire].numeraireToUsdOracleUnit, uint256(rateNumeraireToUsd));
        }
      }
      unchecked {++i;}
    }
    return valuesPerAsset;
  }

  /**
   * @notice Calculate the value per Credit Rating Category of a list of assets denominated in a given Numeraire
   * @param _assetAddresses The List of token addresses of the assets
   * @param _assetIds The list of corresponding token Ids that needs to be checked
   * @dev For each token address, a corresponding id at the same index should be present,
   *  for tokens without Id (ERC20 for instance), the Id should be set to 0
   * @param _assetAmounts The list of corresponding amounts of each Token-Id combination
   * @param numeraire An identifier (uint256) of the Numeraire
   * @return valuesPerCreditRating The list of values per Credit Rating Category denominated in Numeraire
   * @dev Todo: Not yet tested for Over-and underflow
   */
 function getListOfValuesPerCreditRating(
    address[] calldata _assetAddresses, 
    uint256[] calldata _assetIds,
    uint256[] calldata _assetAmounts,
    uint256 numeraire
  ) public view returns (uint256[] memory valuesPerCreditRating) {

    valuesPerCreditRating = new uint256[](CREDIT_RATING_CATOGERIES);
    uint256[] memory valuesPerAsset = getListOfValuesPerAsset(_assetAddresses, _assetIds, _assetAmounts, numeraire);

    uint256 valuesPerAssetLength = valuesPerAsset.length;
    for (uint256 i; i < valuesPerAssetLength;) {
      address assetAdress = _assetAddresses[i];
      valuesPerCreditRating[assetToNumeraireToCreditRating[assetAdress][numeraire]] += valuesPerAsset[i];
      unchecked {++i;}
    }

    return valuesPerCreditRating;
  }

}

/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_two.sol
*/

////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >0.8.10;

////import "../../../AssetRegistry/MainRegistry.sol";
////import "../../../Liquidator.sol";
////import "../../TokenShop.sol";

contract DeployContractsTwo  {

  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function deployMainReg(MainRegistry.NumeraireInformation calldata a) external returns (address) {
    MainRegistry main = new MainRegistry(a);
    main.transferOwnership(msg.sender);
    return address(main);
  }

  function deployLiquidator(address a, address b, address c) external returns (address) {
    Liquidator liq = new Liquidator(a, b, c);
    liq.transferOwnership(msg.sender);
    return address(liq);
  }

  function deployTokenShop(address a) external returns (address) {
    TokenShop ts = new TokenShop(a);
    ts.transferOwnership(msg.sender);
    return address(ts);
  }
  

}

