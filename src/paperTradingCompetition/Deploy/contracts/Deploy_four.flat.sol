
/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

// solhint-disable

/**
 * @dev Reverts if `condition` is false, with a revert reason containing `errorCode`. Only codes up to 999 are
 * supported.
 */
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}

/**
 * @dev Reverts with a revert reason containing `errorCode`. Only codes up to 999 are supported.
 */
function _revert(uint256 errorCode) pure {
    // We're going to dynamically create a revert string based on the error code, with the following format:
    // 'BAL#{errorCode}'
    // where the code is left-padded with zeroes to three digits (so they range from 000 to 999).
    //
    // We don't have revert strings embedded in the contract to save bytecode size: it takes much less space to store a
    // number (8 to 16 bits) than the individual string characters.
    //
    // The dynamic string creation algorithm that follows could be implemented in Solidity, but assembly allows for a
    // much denser implementation, again saving bytecode size. Given this function unconditionally reverts, this is a
    // safe place to rely on it without worrying about how its usage might affect e.g. memory contents.
    assembly {
        // First, we need to compute the ASCII representation of the error code. We assume that it is in the 0-999
        // range, so we only need to convert three digits. To convert the digits to ASCII, we add 0x30, the value for
        // the '0' character.

        let units := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        // With the individual characters, we can now construct the full string. The "BAL#" part is a known constant
        // (0x42414c23): we simply shift this by 24 (to provide space for the 3 bytes of the error code), and add the
        // characters to it, each shifted by a multiple of 8.
        // The revert reason is then shifted left by 200 bits (256 minus the length of the string, 7 characters * 8 bits
        // per character = 56) to locate it in the most significant part of the 256 slot (the beginning of a byte
        // array).

        let revertReason := shl(200, add(0x42414c23000000, add(add(units, shl(8, tenths)), shl(16, hundreds))))

        // We can now encode the reason in memory, which can be safely overwritten as we're about to revert. The encoded
        // message will have the following layout:
        // [ revert reason identifier ] [ string location offset ] [ string length ] [ string contents ]

        // The Solidity revert reason identifier is 0x08c739a0, the function selector of the Error(string) function. We
        // also write zeroes to the next 28 bytes of memory, but those are about to be overwritten.
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        // Next is the offset to the location of the string, which will be placed immediately after (20 bytes away).
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        // The string length is fixed: 7 characters.
        mstore(0x24, 7)
        // Finally, the string itself is stored.
        mstore(0x44, revertReason)

        // Even if the string is only 7 bytes long, we need to return a full 32 byte slot containing it. The length of
        // the encoded message is therefore 4 + 32 + 32 + 32 = 100.
        revert(0, 100)
    }
}

library Errors {
    // Math
    uint256 internal constant ADD_OVERFLOW = 0;
    uint256 internal constant SUB_OVERFLOW = 1;
    uint256 internal constant SUB_UNDERFLOW = 2;
    uint256 internal constant MUL_OVERFLOW = 3;
    uint256 internal constant ZERO_DIVISION = 4;
    uint256 internal constant DIV_INTERNAL = 5;
    uint256 internal constant X_OUT_OF_BOUNDS = 6;
    uint256 internal constant Y_OUT_OF_BOUNDS = 7;
    uint256 internal constant PRODUCT_OUT_OF_BOUNDS = 8;
    uint256 internal constant INVALID_EXPONENT = 9;

    // Input
    uint256 internal constant OUT_OF_BOUNDS = 100;
    uint256 internal constant UNSORTED_ARRAY = 101;
    uint256 internal constant UNSORTED_TOKENS = 102;
    uint256 internal constant INPUT_LENGTH_MISMATCH = 103;
    uint256 internal constant ZERO_TOKEN = 104;

    // Shared pools
    uint256 internal constant MIN_TOKENS = 200;
    uint256 internal constant MAX_TOKENS = 201;
    uint256 internal constant MAX_SWAP_FEE_PERCENTAGE = 202;
    uint256 internal constant MIN_SWAP_FEE_PERCENTAGE = 203;
    uint256 internal constant MINIMUM_BPT = 204;
    uint256 internal constant CALLER_NOT_VAULT = 205;
    uint256 internal constant UNINITIALIZED = 206;
    uint256 internal constant BPT_IN_MAX_AMOUNT = 207;
    uint256 internal constant BPT_OUT_MIN_AMOUNT = 208;
    uint256 internal constant EXPIRED_PERMIT = 209;

    // Pools
    uint256 internal constant MIN_AMP = 300;
    uint256 internal constant MAX_AMP = 301;
    uint256 internal constant MIN_WEIGHT = 302;
    uint256 internal constant MAX_STABLE_TOKENS = 303;
    uint256 internal constant MAX_IN_RATIO = 304;
    uint256 internal constant MAX_OUT_RATIO = 305;
    uint256 internal constant MIN_BPT_IN_FOR_TOKEN_OUT = 306;
    uint256 internal constant MAX_OUT_BPT_FOR_TOKEN_IN = 307;
    uint256 internal constant NORMALIZED_WEIGHT_INVARIANT = 308;
    uint256 internal constant INVALID_TOKEN = 309;
    uint256 internal constant UNHANDLED_JOIN_KIND = 310;
    uint256 internal constant ZERO_INVARIANT = 311;
    uint256 internal constant ORACLE_INVALID_SECONDS_QUERY = 312;
    uint256 internal constant ORACLE_NOT_INITIALIZED = 313;
    uint256 internal constant ORACLE_QUERY_TOO_OLD = 314;
    uint256 internal constant ORACLE_INVALID_INDEX = 315;
    uint256 internal constant ORACLE_BAD_SECS = 316;

    // Lib
    uint256 internal constant REENTRANCY = 400;
    uint256 internal constant SENDER_NOT_ALLOWED = 401;
    uint256 internal constant PAUSED = 402;
    uint256 internal constant PAUSE_WINDOW_EXPIRED = 403;
    uint256 internal constant MAX_PAUSE_WINDOW_DURATION = 404;
    uint256 internal constant MAX_BUFFER_PERIOD_DURATION = 405;
    uint256 internal constant INSUFFICIENT_BALANCE = 406;
    uint256 internal constant INSUFFICIENT_ALLOWANCE = 407;
    uint256 internal constant ERC20_TRANSFER_FROM_ZERO_ADDRESS = 408;
    uint256 internal constant ERC20_TRANSFER_TO_ZERO_ADDRESS = 409;
    uint256 internal constant ERC20_MINT_TO_ZERO_ADDRESS = 410;
    uint256 internal constant ERC20_BURN_FROM_ZERO_ADDRESS = 411;
    uint256 internal constant ERC20_APPROVE_FROM_ZERO_ADDRESS = 412;
    uint256 internal constant ERC20_APPROVE_TO_ZERO_ADDRESS = 413;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_ALLOWANCE = 414;
    uint256 internal constant ERC20_DECREASED_ALLOWANCE_BELOW_ZERO = 415;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_BALANCE = 416;
    uint256 internal constant ERC20_BURN_EXCEEDS_ALLOWANCE = 417;
    uint256 internal constant SAFE_ERC20_CALL_FAILED = 418;
    uint256 internal constant ADDRESS_INSUFFICIENT_BALANCE = 419;
    uint256 internal constant ADDRESS_CANNOT_SEND_VALUE = 420;
    uint256 internal constant SAFE_CAST_VALUE_CANT_FIT_INT256 = 421;
    uint256 internal constant GRANT_SENDER_NOT_ADMIN = 422;
    uint256 internal constant REVOKE_SENDER_NOT_ADMIN = 423;
    uint256 internal constant RENOUNCE_SENDER_NOT_ALLOWED = 424;
    uint256 internal constant BUFFER_PERIOD_EXPIRED = 425;

    // Vault
    uint256 internal constant INVALID_POOL_ID = 500;
    uint256 internal constant CALLER_NOT_POOL = 501;
    uint256 internal constant SENDER_NOT_ASSET_MANAGER = 502;
    uint256 internal constant USER_DOESNT_ALLOW_RELAYER = 503;
    uint256 internal constant INVALID_SIGNATURE = 504;
    uint256 internal constant EXIT_BELOW_MIN = 505;
    uint256 internal constant JOIN_ABOVE_MAX = 506;
    uint256 internal constant SWAP_LIMIT = 507;
    uint256 internal constant SWAP_DEADLINE = 508;
    uint256 internal constant CANNOT_SWAP_SAME_TOKEN = 509;
    uint256 internal constant UNKNOWN_AMOUNT_IN_FIRST_SWAP = 510;
    uint256 internal constant MALCONSTRUCTED_MULTIHOP_SWAP = 511;
    uint256 internal constant INTERNAL_BALANCE_OVERFLOW = 512;
    uint256 internal constant INSUFFICIENT_INTERNAL_BALANCE = 513;
    uint256 internal constant INVALID_ETH_INTERNAL_BALANCE = 514;
    uint256 internal constant INVALID_POST_LOAN_BALANCE = 515;
    uint256 internal constant INSUFFICIENT_ETH = 516;
    uint256 internal constant UNALLOCATED_ETH = 517;
    uint256 internal constant ETH_TRANSFER = 518;
    uint256 internal constant CANNOT_USE_ETH_SENTINEL = 519;
    uint256 internal constant TOKENS_MISMATCH = 520;
    uint256 internal constant TOKEN_NOT_REGISTERED = 521;
    uint256 internal constant TOKEN_ALREADY_REGISTERED = 522;
    uint256 internal constant TOKENS_ALREADY_SET = 523;
    uint256 internal constant TOKENS_LENGTH_MUST_BE_2 = 524;
    uint256 internal constant NONZERO_TOKEN_BALANCE = 525;
    uint256 internal constant BALANCE_TOTAL_OVERFLOW = 526;
    uint256 internal constant POOL_NO_TOKENS = 527;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_BALANCE = 528;

    // Fees
    uint256 internal constant SWAP_FEE_PERCENTAGE_TOO_HIGH = 600;
    uint256 internal constant FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH = 601;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT = 602;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IRM {
  function getYearlyInterestRate(uint256[] memory ValuesPerCreditRating, uint256 minCollValue) external view returns (uint64);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IRegistry {
  function batchIsWhiteListed(address[] calldata assetAddresses, uint256[] calldata assetIds) external view returns (bool);
  function getTotalValue(
                  address[] calldata _assetAddresses, 
                  uint256[] calldata _assetIds,
                  uint256[] calldata _assetAmounts,
                  uint256 numeraire
                ) external view returns (uint256);
  function getListOfValuesPerCreditRating(
                  address[] calldata _assetAddresses, 
                  uint256[] calldata _assetIds,
                  uint256[] calldata _assetAmounts,
                  uint256 numeraire
                ) external view returns (uint256[] memory);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface ILiquidator {
  function startAuction(address vaultAddress, uint256 life, address liquidator, address originalOwner, uint128 openDebt, uint8 liqThres) external returns (bool);
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC1155 {
  function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
  }



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC721 {
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function ownerOf(uint256 tokenId) external view returns (address owner);
  function transferFrom(address from, address to, uint256 id) external;
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: MIT
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the “Software”), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

pragma solidity ^0.8.0;

////import "./BalancerErrors.sol";

/* solhint-disable */

/**
 * @dev Exponentiation and logarithm functions for 18 decimal fixed point numbers (both base and exponent/argument).
 *
 * Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural
 * exponentiation and logarithm (where the base is Euler's number).
 *
 * @author Fernando Martinelli - @fernandomartinelli
 * @author Sergio Yuhjtman - @sergioyuhjtman
 * @author Daniel Fernandez - @dmf7z
 */
library LogExpMath {
    // All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
    // two numbers, and multiply by ONE when dividing them.

    // All arguments and return values are 18 decimal fixed point numbers.
    int256 constant ONE_18 = 1e18;

    // Internally, intermediate values are computed with higher precision as 20 decimal fixed point numbers, and in the
    // case of ln36, 36 decimals.
    int256 constant ONE_20 = 1e20;
    int256 constant ONE_36 = 1e36;

    // The domain of natural exponentiation is bound by the word size and number of decimals used.
    //
    // Because internally the result will be stored using 20 decimals, the largest possible result is
    // (2^255 - 1) / 10^20, which makes the largest exponent ln((2^255 - 1) / 10^20) = 130.700829182905140221.
    // The smallest possible result is 10^(-18), which makes largest negative argument
    // ln(10^(-18)) = -41.446531673892822312.
    // We use 130.0 and -41.0 to have some safety margin.
    int256 constant MAX_NATURAL_EXPONENT = 130e18;
    int256 constant MIN_NATURAL_EXPONENT = -41e18;

    // Bounds for ln_36's argument. Both ln(0.9) and ln(1.1) can be represented with 36 decimal places in a fixed point
    // 256 bit integer.
    int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
    int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;

    uint256 constant MILD_EXPONENT_BOUND = 2**254 / uint256(ONE_20);

    // 18 decimal constants
    int256 constant x0 = 128000000000000000000; // 2ˆ7
    int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; // eˆ(x0) (no decimals)
    int256 constant x1 = 64000000000000000000; // 2ˆ6
    int256 constant a1 = 6235149080811616882910000000; // eˆ(x1) (no decimals)

    // 20 decimal constants
    int256 constant x2 = 3200000000000000000000; // 2ˆ5
    int256 constant a2 = 7896296018268069516100000000000000; // eˆ(x2)
    int256 constant x3 = 1600000000000000000000; // 2ˆ4
    int256 constant a3 = 888611052050787263676000000; // eˆ(x3)
    int256 constant x4 = 800000000000000000000; // 2ˆ3
    int256 constant a4 = 298095798704172827474000; // eˆ(x4)
    int256 constant x5 = 400000000000000000000; // 2ˆ2
    int256 constant a5 = 5459815003314423907810; // eˆ(x5)
    int256 constant x6 = 200000000000000000000; // 2ˆ1
    int256 constant a6 = 738905609893065022723; // eˆ(x6)
    int256 constant x7 = 100000000000000000000; // 2ˆ0
    int256 constant a7 = 271828182845904523536; // eˆ(x7)
    int256 constant x8 = 50000000000000000000; // 2ˆ-1
    int256 constant a8 = 164872127070012814685; // eˆ(x8)
    int256 constant x9 = 25000000000000000000; // 2ˆ-2
    int256 constant a9 = 128402541668774148407; // eˆ(x9)
    int256 constant x10 = 12500000000000000000; // 2ˆ-3
    int256 constant a10 = 113314845306682631683; // eˆ(x10)
    int256 constant x11 = 6250000000000000000; // 2ˆ-4
    int256 constant a11 = 106449445891785942956; // eˆ(x11)

    /**
     * @dev Exponentiation (x^y) with unsigned 18 decimal fixed point base and exponent.
     *
     * Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) {
            // We solve the 0^0 indetermination by making it equal one.
            return uint256(ONE_18);
        }

        if (x == 0) {
            return 0;
        }

        // Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
        // arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
        // x^y = exp(y * ln(x)).

        // The ln function takes a signed value, so we need to make sure x fits in the signed 256 bit range.
        _require(x < 2**255, Errors.X_OUT_OF_BOUNDS);
        int256 x_int256 = int256(x);

        // We will compute y * ln(x) in a single step. Depending on the value of x, we can either use ln or ln_36. In
        // both cases, we leave the division by ONE_18 (due to fixed point multiplication) to the end.

        // This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 256 bit range.
        _require(y < MILD_EXPONENT_BOUND, Errors.Y_OUT_OF_BOUNDS);
        int256 y_int256 = int256(y);

        int256 logx_times_y;
        if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
            int256 ln_36_x = _ln_36(x_int256);

            // ln_36_x has 36 decimal places, so multiplying by y_int256 isn't as straightforward, since we can't just
            // bring y_int256 to 36 decimal places, as it might overflow. Instead, we perform two 18 decimal
            // multiplications and add the results: one with the first 18 decimals of ln_36_x, and one with the
            // (downscaled) last 18 decimals.
            logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
        } else {
            logx_times_y = _ln(x_int256) * y_int256;
        }
        logx_times_y /= ONE_18;

        // Finally, we compute exp(y * ln(x)) to arrive at x^y
        _require(
            MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT,
            Errors.PRODUCT_OUT_OF_BOUNDS
        );

        return uint256(exp(logx_times_y));
    }

    /**
     * @dev Natural exponentiation (e^x) with signed 18 decimal fixed point exponent.
     *
     * Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function exp(int256 x) internal pure returns (int256) {
        _require(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT, Errors.INVALID_EXPONENT);

        if (x < 0) {
            // We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
            // fits in the signed 256 bit range (as it is larger than MIN_NATURAL_EXPONENT).
            // Fixed point division requires multiplying by ONE_18.
            return ((ONE_18 * ONE_18) / exp(-x));
        }

        // First, we use the fact that e^(x+y) = e^x * e^y to decompose x into a sum of powers of two, which we call x_n,
        // where x_n == 2^(7 - n), and e^x_n = a_n has been precomputed. We choose the first x_n, x0, to equal 2^7
        // because all larger powers are larger than MAX_NATURAL_EXPONENT, and therefore not present in the
        // decomposition.
        // At the end of this process we will have the product of all e^x_n = a_n that apply, and the remainder of this
        // decomposition, which will be lower than the smallest x_n.
        // exp(x) = k_0 * a_0 * k_1 * a_1 * ... + k_n * a_n * exp(remainder), where each k_n equals either 0 or 1.
        // We mutate x by subtracting x_n, making it the remainder of the decomposition.

        // The first two a_n (e^(2^7) and e^(2^6)) are too large if stored as 18 decimal numbers, and could cause
        // intermediate overflows. Instead we store them as plain integers, with 0 decimals.
        // Additionally, x0 + x1 is larger than MAX_NATURAL_EXPONENT, which means they will not both be present in the
        // decomposition.

        // For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
        // it and compute the accumulated product.

        int256 firstAN;
        if (x >= x0) {
            x -= x0;
            firstAN = a0;
        } else if (x >= x1) {
            x -= x1;
            firstAN = a1;
        } else {
            firstAN = 1; // One with no decimal places
        }

        // We now transform x into a 20 decimal fixed point number, to have enhanced precision when computing the
        // smaller terms.
        x *= 100;

        // `product` is the accumulated product of all a_n (except a0 and a1), which starts at 20 decimal fixed point
        // one. Recall that fixed point multiplication requires dividing by ONE_20.
        int256 product = ONE_20;

        if (x >= x2) {
            x -= x2;
            product = (product * a2) / ONE_20;
        }
        if (x >= x3) {
            x -= x3;
            product = (product * a3) / ONE_20;
        }
        if (x >= x4) {
            x -= x4;
            product = (product * a4) / ONE_20;
        }
        if (x >= x5) {
            x -= x5;
            product = (product * a5) / ONE_20;
        }
        if (x >= x6) {
            x -= x6;
            product = (product * a6) / ONE_20;
        }
        if (x >= x7) {
            x -= x7;
            product = (product * a7) / ONE_20;
        }
        if (x >= x8) {
            x -= x8;
            product = (product * a8) / ONE_20;
        }
        if (x >= x9) {
            x -= x9;
            product = (product * a9) / ONE_20;
        }

        // x10 and x11 are unnecessary here since we have high enough precision already.

        // Now we need to compute e^x, where x is small (in particular, it is smaller than x9). We use the Taylor series
        // expansion for e^x: 1 + x + (x^2 / 2!) + (x^3 / 3!) + ... + (x^n / n!).

        int256 seriesSum = ONE_20; // The initial one in the sum, with 20 decimal places.
        int256 term; // Each term in the sum, where the nth term is (x^n / n!).

        // The first term is simply x.
        term = x;
        seriesSum += term;

        // Each term (x^n / n!) equals the previous one times x, divided by n. Since x is a fixed point number,
        // multiplying by it requires dividing by ONE_20, but dividing by the non-fixed point n values does not.

        term = ((term * x) / ONE_20) / 2;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 3;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 4;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 5;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 6;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 7;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 8;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 9;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 10;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 11;
        seriesSum += term;

        term = ((term * x) / ONE_20) / 12;
        seriesSum += term;

        // 12 Taylor terms are sufficient for 18 decimal precision.

        // We now have the first a_n (with no decimals), and the product of all other a_n present, and the Taylor
        // approximation of the exponentiation of the remainder (both with 20 decimals). All that remains is to multiply
        // all three (one 20 decimal fixed point multiplication, dividing by ONE_20, and one integer multiplication),
        // and then drop two digits to return an 18 decimal value.

        return (((product * seriesSum) / ONE_20) * firstAN) / 100;
    }

    /**
     * @dev Internal natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
     */
    function _ln(int256 a) private pure returns (int256) {
        if (a < ONE_18) {
            // Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)). If a is less
            // than one, 1/a will be greater than one, and this if statement will not be entered in the recursive call.
            // Fixed point division requires multiplying by ONE_18.
            return (-_ln((ONE_18 * ONE_18) / a));
        }

        // First, we use the fact that ln^(a * b) = ln(a) + ln(b) to decompose ln(a) into a sum of powers of two, which
        // we call x_n, where x_n == 2^(7 - n), which are the natural logarithm of precomputed quantities a_n (that is,
        // ln(a_n) = x_n). We choose the first x_n, x0, to equal 2^7 because the exponential of all larger powers cannot
        // be represented as 18 fixed point decimal numbers in 256 bits, and are therefore larger than a.
        // At the end of this process we will have the sum of all x_n = ln(a_n) that apply, and the remainder of this
        // decomposition, which will be lower than the smallest a_n.
        // ln(a) = k_0 * x_0 + k_1 * x_1 + ... + k_n * x_n + ln(remainder), where each k_n equals either 0 or 1.
        // We mutate a by subtracting a_n, making it the remainder of the decomposition.

        // For reasons related to how `exp` works, the first two a_n (e^(2^7) and e^(2^6)) are not stored as fixed point
        // numbers with 18 decimals, but instead as plain integers with 0 decimals, so we need to multiply them by
        // ONE_18 to convert them to fixed point.
        // For each a_n, we test if that term is present in the decomposition (if a is larger than it), and if so divide
        // by it and compute the accumulated sum.

        int256 sum = 0;
        if (a >= a0 * ONE_18) {
            a /= a0; // Integer, not fixed point division
            sum += x0;
        }

        if (a >= a1 * ONE_18) {
            a /= a1; // Integer, not fixed point division
            sum += x1;
        }

        // All other a_n and x_n are stored as 20 digit fixed point numbers, so we convert the sum and a to this format.
        sum *= 100;
        a *= 100;

        // Because further a_n are  20 digit fixed point numbers, we multiply by ONE_20 when dividing by them.

        if (a >= a2) {
            a = (a * ONE_20) / a2;
            sum += x2;
        }

        if (a >= a3) {
            a = (a * ONE_20) / a3;
            sum += x3;
        }

        if (a >= a4) {
            a = (a * ONE_20) / a4;
            sum += x4;
        }

        if (a >= a5) {
            a = (a * ONE_20) / a5;
            sum += x5;
        }

        if (a >= a6) {
            a = (a * ONE_20) / a6;
            sum += x6;
        }

        if (a >= a7) {
            a = (a * ONE_20) / a7;
            sum += x7;
        }

        if (a >= a8) {
            a = (a * ONE_20) / a8;
            sum += x8;
        }

        if (a >= a9) {
            a = (a * ONE_20) / a9;
            sum += x9;
        }

        if (a >= a10) {
            a = (a * ONE_20) / a10;
            sum += x10;
        }

        if (a >= a11) {
            a = (a * ONE_20) / a11;
            sum += x11;
        }

        // a is now a small number (smaller than a_11, which roughly equals 1.06). This means we can use a Taylor series
        // that converges rapidly for values of `a` close to one - the same one used in ln_36.
        // Let z = (a - 1) / (a + 1).
        // ln(a) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

        // Recall that 20 digit fixed point division requires multiplying by ONE_20, and multiplication requires
        // division by ONE_20.
        int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
        int256 z_squared = (z * z) / ONE_20;

        // num is the numerator of the series: the z^(2 * n + 1) term
        int256 num = z;

        // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
        int256 seriesSum = num;

        // In each step, the numerator is multiplied by z^2
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 3;

        num = (num * z_squared) / ONE_20;
        seriesSum += num / 5;

        num = (num * z_squared) / ONE_20;
        seriesSum += num / 7;

        num = (num * z_squared) / ONE_20;
        seriesSum += num / 9;

        num = (num * z_squared) / ONE_20;
        seriesSum += num / 11;

        // 6 Taylor terms are sufficient for 36 decimal precision.

        // Finally, we multiply by 2 (non fixed point) to compute ln(remainder)
        seriesSum *= 2;

        // We now have the sum of all x_n present, and the Taylor approximation of the logarithm of the remainder (both
        // with 20 decimals). All that remains is to sum these two, and then drop two digits to return a 18 decimal
        // value.

        return (sum + seriesSum) / 100;
    }

    /**
     * @dev Intrnal high precision (36 decimal places) natural logarithm (ln(x)) with signed 18 decimal fixed point argument,
     * for x close to one.
     *
     * Should only be used if x is between LN_36_LOWER_BOUND and LN_36_UPPER_BOUND.
     */
    function _ln_36(int256 x) private pure returns (int256) {
        // Since ln(1) = 0, a value of x close to one will yield a very small result, which makes using 36 digits
        // worthwhile.

        // First, we transform x to a 36 digit fixed point value.
        x *= ONE_18;

        // We will use the following Taylor expansion, which converges very rapidly. Let z = (x - 1) / (x + 1).
        // ln(x) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

        // Recall that 36 digit fixed point division requires multiplying by ONE_36, and multiplication requires
        // division by ONE_36.
        int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
        int256 z_squared = (z * z) / ONE_36;

        // num is the numerator of the series: the z^(2 * n + 1) term
        int256 num = z;

        // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
        int256 seriesSum = num;

        // In each step, the numerator is multiplied by z^2
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 3;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 5;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 7;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 9;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 11;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 13;

        num = (num * z_squared) / ONE_36;
        seriesSum += num / 15;

        // 8 Taylor terms are sufficient for 36 decimal precision.

        // All that remains is multiplying by 2 (non fixed point).
        return seriesSum * 2;
    }
}

contract mathtest {

    function pow(uint256 base, uint256 power) public pure returns (uint256) {
        return LogExpMath.pow(base, power);
    }
}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.8 <0.9.0;

////import "./utils/LogExpMath.sol";
////import "./interfaces/IERC20.sol";
////import "./interfaces/IERC721.sol";
////import "./interfaces/IERC1155.sol";
////import "./interfaces/ILiquidator.sol";
////import "./interfaces/IRegistry.sol";
////import "./interfaces/IRM.sol";
////import "./interfaces/IMainRegistry.sol";


/** 
  * @title An Arcadia Vault used to deposit a combination of all kinds of assets
  * @author Arcadia Finance
  * @notice Users can use this vault to deposit assets (ERC20, ERC721, ERC1155, ...). 
            The vault will denominate all the pooled assets into one numeraire.
            An increase of value of one asset will offset a decrease in value of another asset.
            Users can take out a credit line against the single denominated value.
            Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
  * @dev A vault is a smart contract that will contain multiple assets.
         Using getValue(<numeraire>), the vault returns the combined total value of all (whitelisted) assets the vault contains.
         Integrating this vault as means of collateral management for your own protocol that requires collateral is encouraged.
         Arcadia's vault functions will guarantee you a certain value of the vault.
         For whitelists or liquidation strategies specific to your protocol, contact: dev at arcadia.finance
 */ 
contract Vault {

  uint256 public constant yearlyBlocks = 2628000;

  /*///////////////////////////////////////////////////////////////
                INTERNAL BOOKKEEPING OF DEPOSITED ASSETS
  ///////////////////////////////////////////////////////////////*/
  address[] public _erc20Stored;
  address[] public _erc721Stored;
  address[] public _erc1155Stored;

  uint256[] public _erc721TokenIds;
  uint256[] public _erc1155TokenIds;

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL CONTRACTS
  ///////////////////////////////////////////////////////////////*/
  address public _registryAddress; /// to be fetched somewhere else?
  address public _stable;
  address public _stakeContract;
  address public _irmAddress;

  // Each vault has a certain 'life', equal to the amount of times the vault is liquidated.
  // Used by the liquidator contract for proceed claims
  uint256 public life;

  address public owner; 


  bool public initialized;

  struct debtInfo {
    uint128 _openDebt;
    uint16 _collThres; //factor 100
    uint8 _liqThres; //factor 100
    uint64 _yearlyInterestRate; //factor 10**18
    uint32 _lastBlock;
    uint8 _numeraire;
  }

  debtInfo public debt;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  // set the vault logic implementation to the msg.sender
  // NOTE: this does not represent the owner of the proxy vault!
  //       The owner of this contract (not the derived proxies) 
  //       should not have any privilages!
  constructor() {
  }

    /**
   * @dev Throws if called by any account other than the factory adress.
   */
  modifier onlyFactory() {
    require(msg.sender == IMainRegistry(_registryAddress).factoryAddress(), "VL: Not factory");
    _;
  }

  /*///////////////////////////////////////////////////////////////
                  REDUCED & MODIFIED OPENZEPPELIN OWNABLE
      Reduced to functions needed, while modified to allow
      a transfer of ownership of this vault by a transfer
      of ownership of the accompanying ERC721 Vault NFT
      issued by the factory. Owner of Vault NFT = owner of vault
  ///////////////////////////////////////////////////////////////*/

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public onlyFactory {
    if (newOwner == address(0)) {
      revert("New owner cannot be zero address upon liquidation");
    }
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = owner;
    owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }

  /** 
    @notice Initiates the variables of the vault
    @dev A proxy will be used to interact with the vault logic.
         Therefore everything is initialised through an init function.
         This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
         Costly function (156k gas)
    @param _owner The tx.origin: the sender of the 'createVault' on the factory
    @param registryAddress The 'beacon' contract to which should be looked at for external logic.
    @param stable The contract address of the stablecoin of Arcadia Finance
    @param stakeContract The stake contract in which stablecoin can be staked. 
                         Used when syncing debt: interest in stable is minted to stakecontract.
    @param irmAddress The contract address of the InterestRateModule, which calculates the going interest rate
                      for a credit line, based on the underlying assets.
  */
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address irmAddress) external payable virtual {
    require(initialized == false);
    _registryAddress = registryAddress;
    owner = _owner;
    debt._collThres = 150;
    debt._liqThres = 110;
    _stable = stable;
    _stakeContract = stakeContract;
    _irmAddress = irmAddress;

    initialized = true;
  }

  /** 
    @notice The function used to deposit assets into the proxy vault by the proxy vault owner.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get deposited. If multiple asset IDs of the same contract address
         are deposited, the assetAddress must be repeated in assetAddresses.
         The ERC20 get deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner to avoid attacks where malicous actors can deposit 1 wei assets,
         increasing gas costs upon credit issuance and withrawals.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be deposited one address,
                          even if multiple assets of the same contract address are deposited.
    @param assetIds The asset IDs that will be deposited for ERC721 & ERC1155. 
                    When depositing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be deposited. 
    @param assetTypes The types of the assets to be deposited.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable virtual onlyOwner {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    

    require(IRegistry(_registryAddress).batchIsWhiteListed(assetAddresses, assetIds), "Not all assets are whitelisted!");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _depositERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _depositERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _depositERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  ////////
  function getLengths() public view returns (uint256, uint256, uint256, uint256) {
    return (_erc20Stored.length, _erc721Stored.length, _erc721TokenIds.length, _erc1155Stored.length);
  }

  function returnLists() public view returns (address[] memory, address[] memory, uint256[] memory, address[] memory, uint256[] memory) {
    return (_erc20Stored, _erc721Stored, _erc721TokenIds, _erc1155Stored, _erc1155TokenIds);
  }

  function getValueGas(uint8 numeraire) public view returns (uint256) {
    return getValue(numeraire);
  }

  function viewReq(uint256 amount) public view returns (uint256) {
    return (getValue(debt._numeraire) * 100) / (getOpenDebt() + amount);
  }
  ////////

  /** 
    @notice Internal function used to deposit ERC20 tokens.
    @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
         After successful transfer, the function checks whether the same asset has been deposited. 
         This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
         If the address has not yet been seen, the ERC20 token address is stored.
    @param _from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC20Address The asset address that should be transferred.
    @param amount The amount of ERC20 tokens to be transferred.
  */
  function _depositERC20(address _from, address ERC20Address, uint256 amount) internal {

    require(IERC20(ERC20Address).transferFrom(_from, address(this), amount), "Transfer from failed");

    bool addrSeen;
    uint256 erc20StoredLength = _erc20Stored.length;
    for (uint256 i; i < erc20StoredLength;) {
      if (_erc20Stored[i] == ERC20Address) {
        addrSeen = true;
        break;
      }
      unchecked {++i;}
    }

    if (!addrSeen) {
      _erc20Stored.push(ERC20Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
    }
  }

  /** 
    @notice Internal function used to deposit ERC721 tokens.
    @dev Used for all tokens types = 1. Note the safeTransferFrom. No amounts are given since ERC721 are one-off's.
         After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
         This may cause duplicates in the ERC721 stored addresses array, but this is intended. 
    @param _from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC721Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
  */
  function _depositERC721(address _from, address ERC721Address, uint256 id) internal {
    
    IERC721(ERC721Address).transferFrom(_from, address(this), id);
    
    _erc721Stored.push(ERC721Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
    _erc721TokenIds.push(id);
  }

  /** 
    @notice Internal function used to deposit ERC1155 tokens.
    @dev Used for all tokens types = 2. Note the safeTransferFrom.
         After successful transfer, the function checks whether the combination of address & ID has already been stored.
         If not, the function pushes the new address and ID to the stored arrays.
         This may cause duplicates in the ERC1155 stored addresses array, but this is intended. 
    @param _from TAddress the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC1155Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
    @param amount The amount of ERC1155 tokens to be transferred.
  */
  function _depositERC1155(address _from, address ERC1155Address, uint256 id, uint256 amount) internal {

      IERC1155(ERC1155Address).safeTransferFrom(_from, address(this), id, amount, "");

      bool addrSeen;

      uint256 erc1155StoredLength = _erc1155Stored.length;
      for (uint256 i; i < erc1155StoredLength;) {
        if (_erc1155Stored[i] == ERC1155Address) {
          if (_erc1155TokenIds[i] == id) {
            addrSeen = true;
            break;
          }
        }
        unchecked {++i;}
      }

      if (!addrSeen) {
        _erc1155Stored.push(ERC1155Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
        _erc1155TokenIds.push(id);
      }
  }

  /** 
    @notice Processes withdrawals of assets by and to the owner of the proxy vault.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
         are to be withdrawn, the assetAddress must be repeated in assetAddresses.
         The ERC20 get withdrawn by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner.
         Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
         Will fail if "the value after withdrawal / open debt (including unrealised debt) > collateral threshold".
         If no debt is taken yet on this proxy vault, users are free to withraw any asset at any time.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be withdrawn one address,
                          even if multiple assets of the same contract address are withdrawn.
    @param assetIds The asset IDs that will be withdrawn for ERC721 & ERC1155. 
                    When withdrawing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be withdrawn. 
    @param assetTypes The types of the assets to be withdrawn.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable virtual onlyOwner {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        _withdrawERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        _withdrawERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        _withdrawERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

    uint256 openDebt = getOpenDebt();
    if (openDebt != 0) {
      require((getValue(debt._numeraire) * 100 / openDebt) > debt._collThres , "Cannot withdraw since the collateral value would become too low!" );
    }

  }

  /** 
    @notice Internal function used to withdraw ERC20 tokens.
    @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
         After successful transfer, the function checks whether the proxy vault has any leftover balance of said asset.
         If not, it will pop() the ERC20 asset address from the stored addresses array.
         Note: this shifts the order of _erc20Stored! 
         This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
    @param to Address the tokens should be sent to. This will in any case be the proxy vault owner
              either being the original user or the liquidator!.
    @param ERC20Address The asset address that should be transferred.
    @param amount The amount of ERC20 tokens to be transferred.
  */
  function _withdrawERC20(address to, address ERC20Address, uint256 amount) internal {

    require(IERC20(ERC20Address).transfer(to, amount), "Transfer from failed");

    if (IERC20(ERC20Address).balanceOf(address(this)) == 0) {
      uint256 erc20StoredLength = _erc20Stored.length;
      for (uint256 i; i < erc20StoredLength;) {
        if (_erc20Stored[i] == ERC20Address) {
          _erc20Stored[i] = _erc20Stored[erc20StoredLength-1];
          _erc20Stored.pop();
          break;
        }
        unchecked {++i;}
      }
    }
  }

  /** 
    @notice Internal function used to withdraw ERC721 tokens.
    @dev Used for all tokens types = 1. Note the safeTransferFrom. No amounts are given since ERC721 are one-off's.
         After successful transfer, the function checks whether any other ERC721 is deposited in the proxy vault.
         If not, it pops the stored addresses and stored IDs (pop() of two arrs is 180 gas cheaper than deleting).
         If there are, it loops through the stored arrays and searches the ID that's withdrawn, 
         then replaces it with the last index, followed by a pop().
         Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
    @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC721Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
  */
  function _withdrawERC721(address to, address ERC721Address, uint256 id) internal {

    uint256 tokenIdLength = _erc721TokenIds.length;

    if (tokenIdLength == 1) { // there was only one ERC721 stored on the contract, safe to remove both lists
      _erc721TokenIds.pop();
      _erc721Stored.pop();
    }
    else {
      for (uint256 i; i < tokenIdLength;) {
        if (_erc721TokenIds[i] == id && _erc721Stored[i] == ERC721Address) {
          _erc721TokenIds[i] = _erc721TokenIds[tokenIdLength-1];
          _erc721TokenIds.pop();
          _erc721Stored[i] = _erc721Stored[tokenIdLength-1];
          _erc721Stored.pop();
          break;
        }
        unchecked {++i;}
      }
    }

    IERC721(ERC721Address).safeTransferFrom(address(this), to, id);

  }

  /** 
    @notice Internal function used to withdraw ERC1155 tokens.
    @dev Used for all tokens types = 2. Note the safeTransferFrom.
         After successful transfer, the function checks whether there is any balance left for that ERC1155.
         If there is, it simply transfers the tokens.
         If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
         If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
         and then replaces it with the last index, followed by a pop().
         Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
    @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC1155Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
    @param amount The amount of ERC1155 tokens to be transferred.
  */
  function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount) internal {

    uint256 tokenIdLength = _erc1155TokenIds.length;
    if (IERC1155(ERC1155Address).balanceOf(address(this), id) - amount == 0) {
      if (tokenIdLength == 1) {
        _erc1155TokenIds.pop();
        _erc1155Stored.pop();
      }
      else {
        for (uint256 i; i < tokenIdLength;) {
          if (_erc1155TokenIds[i] == id) {
            if (_erc1155Stored[i] == ERC1155Address) {
            _erc1155TokenIds[i] = _erc1155TokenIds[tokenIdLength-1];
             _erc1155TokenIds.pop();
            _erc1155Stored[i] = _erc1155Stored[tokenIdLength-1];
            _erc1155Stored.pop();
            break;
            }
          }
          unchecked {++i;}
        }
      }
    }

    IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
  }

  /** 
    @notice Generates three arrays about the stored assets in the proxy vault
            in the format needed for vault valuation functions.
    @dev No balances are stored on the contract. Both for gas savings upon deposit and to allow for rebasing/... tokens.
         Loops through the stored asset addresses and fills the arrays. 
         The vault valuation function fetches the asset type through the asset registries.
         There is no ////importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
    @return assetAddresses An array of asset addresses.
    @return assetIds An array of asset IDs. Will be '0' for ERC20's
    @return assetAmounts An array of the amounts/balances of the asset on the proxy vault. wil be '1' for ERC721's
  */
  function generateAssetData() public view returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) {
    uint256 totalLength;
    unchecked{totalLength = _erc20Stored.length + _erc721Stored.length + _erc1155Stored.length;} //cannot practiaclly overflow. No max(uint256) contracts deployed
    assetAddresses = new address[](totalLength);
    assetIds = new uint256[](totalLength);
    assetAmounts = new uint256[](totalLength);

    uint256 i;
    uint256 erc20StoredLength = _erc20Stored.length;
    address cacheAddr;
    for (; i < erc20StoredLength;) {
      cacheAddr = _erc20Stored[i];
      assetAddresses[i] = cacheAddr;
      //assetIds[i] = 0; //gas: no need to store 0, index will continue anyway
      assetAmounts[i] = IERC20(cacheAddr).balanceOf(address(this));
      unchecked {++i;}
    }

    uint256 j;
    uint256 erc721StoredLength = _erc721Stored.length;
    for (; j < erc721StoredLength;) {
      cacheAddr = _erc721Stored[j];
      assetAddresses[i] = cacheAddr;
      assetIds[i] = _erc721TokenIds[j];
      assetAmounts[i] = 1;
      unchecked {++i;}
      unchecked {++j;}
    }

    uint256 k;
    uint256 erc1155StoredLength = _erc1155Stored.length;
    for (; k < erc1155StoredLength;) {
      cacheAddr = _erc1155Stored[k];
      assetAddresses[i] = cacheAddr;
      assetIds[i] = _erc1155TokenIds[k];
      assetAmounts[i] = IERC1155(cacheAddr).balanceOf(address(this), _erc1155TokenIds[k]);
      unchecked {++i;}
      unchecked {++k;}
    }
  }

  /** 
    @notice Returns the total value of the vault in a specific numeraire (0 = USD, 1 = ETH, more can be added)
    @dev Fetches all stored assets with their amounts on the proxy vault.
         Using a specified numeraire, fetches the value of all assets on the proxy vault in said numeraire.
    @param numeraire Numeraire to return the value in. For example, 0 (USD) or 1 (ETH).
    @return vaultValue Total value stored on the vault, expressed in numeraire.
  */
  function getValue(uint8 numeraire) public view returns (uint256 vaultValue) {
    (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) = generateAssetData();
    vaultValue = getValueOfAssets(numeraire, assetAddresses, assetIds, assetAmounts);
  }

  /** 
    @notice Returns the total value of the assets provided as input.
    @dev Although mostly an internal function, it's put public such that users/... can estimate the combined value of a series of assets
         without them having to be stored on the vault.
    @param numeraire Numeraire to return the value in. For example, 0 (USD) or 1 (ETH).
    @param assetAddresses A list of all asset addresses. Index in the three arrays are concerning the same asset.
    @param assetIds  A list of all asset IDs. Can be '0' for ERC20s. Index in the three arrays are concerning the same asset.
    @param assetAmounts A list of all amounts. Will be '1' for ERC721's. Index in the three arrays are concerning the same asset.
    @return vaultValue Total value of the given assets, expressed in numeraire.
  */
  function getValueOfAssets(uint8 numeraire, address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) public view returns (uint256 vaultValue) {
    // needs to check whether all assets are actually owned
    // -> not be done twice since this function is called by getValue which already has that check
    // should account for a 'must stop at value x'
    // stop at value x should be done in lower contract
    // extra input: stop value

    vaultValue = IRegistry(_registryAddress).getTotalValue(assetAddresses, assetIds, assetAmounts, numeraire);
  }


  ///////////////
  ///////////////
  ///////////////

  /** 
    @notice Calculates the yearly interest (in 1e18 decimals).
    @dev Based on an array with values per credit rating (tranches) and the minimum collateral value needed for the debt taken,
         returns the yearly interest rate in a 1e18 decimal number.
    @param valuesPerCreditRating An array of values, split per credit rating.
    @param minCollValue The minimum collateral value based on the amount of open debt on the proxy vault.
    @return yearlyInterestRate The yearly interest rate in a 1e18 decimal number.
  */
  function calculateYearlyInterestRate(uint256[] memory valuesPerCreditRating, uint256 minCollValue) public view returns (uint64 yearlyInterestRate) {
    yearlyInterestRate = IRM(_irmAddress).getYearlyInterestRate(valuesPerCreditRating, minCollValue);
  }

  /** 
    @notice Internal function: sets the yearly interest rate (in a 1e18 decimal).
    @param valuesPerCreditRating An array of values, split per credit rating.
    @param minCollValue The minimum collateral value based on the amount of open debt on the proxy vault.
  */
  function _setYearlyInterestRate(uint256[] memory valuesPerCreditRating, uint256 minCollValue) private {
    debt._yearlyInterestRate = calculateYearlyInterestRate(valuesPerCreditRating, minCollValue);
  }

  /** 
    @notice Sets the yearly interest rate of the proxy vault, in the form of a 1e18 decimal number.
    @dev First syncs all debt to realise all unrealised debt. Fetches all the asset data and queries the
         Registry to obtain an array of values, split up according to the credit rating of the underlying assets.
  */
  function setYearlyInterestRate() public {
    syncDebt();
    uint256 minCollValue;
    //gas: can't overflow: uint128 * uint16 << uint256
    unchecked {minCollValue = uint256(debt._openDebt) * debt._collThres / 100;} 
    (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) = generateAssetData();
    uint256[] memory ValuesPerCreditRating = IRegistry(_registryAddress).getListOfValuesPerCreditRating(assetAddresses, assetIds, assetAmounts, debt._numeraire);

    _setYearlyInterestRate(ValuesPerCreditRating, minCollValue);
  }

  /** 
    @notice Can be called by the proxy vault owner to take out (additional) credit against
            his assets stored on the proxy vault.
    @dev amount to be provided in stablecoin decimals. 
    @param amount The amount of credit to take out, in the form of a pegged stablecoin with 18 decimals.
  */
  function takeCredit(uint128 amount) public onlyOwner {
    (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) = generateAssetData();
    _takeCredit(amount, assetAddresses, assetIds, assetAmounts);
  }

  // https://twitter.com/0x_beans/status/1502420621250105346
  /** 
    @notice Returns the sum of all uints in an array.
    @param _data An uint256 array.
    @return sum The combined sum of uints in the array.
  */
  function sumElementsOfList(uint[] memory _data) public payable returns (uint sum) {
    //cache
    uint256 len = _data.length;

    for (uint i = 0; i < len;) {
        // optimizooooor
        assembly {
            sum := add(sum, mload(add(add(_data, 0x20), mul(i, 0x20))))
        }

        // iykyk
        unchecked {++i;}
    }
  }
  
  /** 
    @notice Syncs all unrealised debt (= interest) on the proxy vault.
    @dev Public function, can be called by any user to keep the game fair and to allow keeps to
         sync the debt before in case a liquidation can be triggered.
         To Find the unrealised debt over an amount of time, you need to calculate D[(1+r)^x-1].
         The base of the exponential: 1 + r, is a 18 decimals fixed point number
         with r the yearly interest rate.
         The exponent of the exponential: x, is a 18 decimals fixed point number.
         The exponent x is calculated as: the amount of blocks since last sync divided by the average of 
         blocks produced over a year (using a 12s average block time).
         Any debt being realised will be accompanied by a mint of stablecoin of equal amounts.
         Bookkeeping requires total open (realised) debt of the system = totalsupply of stablecoin.
         _yearlyInterestRate = 1 + r expressed as 18 decimals fixed point number
  */
  function syncDebt() public {
    uint128 base;
    uint128 exponent;
    uint128 unRealisedDebt;
    
    unchecked {
      //gas: can't overflow: 1e18 + uint64 <<< uint128
      base = uint128(1e18) + debt._yearlyInterestRate;

      //gas: only overflows when blocks.number > 894262060268226281981748468
      //in practice: assumption that delta of blocks < 341640000 (150 years)
      //as foreseen in LogExpMath lib
      exponent = uint128((block.number - debt._lastBlock) * 1e18 / yearlyBlocks);

      //gas: taking an imaginary worst-case D- tier assets with max interest of 1000%
      //over a period of 5 years
      //this won't overflow as long as opendebt < 3402823669209384912995114146594816
      //which is 3.4 million billion *10**18 decimals

      unRealisedDebt = uint128(debt._openDebt * (LogExpMath.pow(base, exponent) - 1e18) / 1e18);
    }

    //gas: could go unchecked as well, but might result in opendebt = 0 on overflow
    debt._openDebt += unRealisedDebt;
    debt._lastBlock = uint32(block.number);

    if (unRealisedDebt > 0) {
      IERC20(_stable).mint(_stakeContract, unRealisedDebt);
    }
  }

  /** 
    @notice Internal function to take out credit.
    @dev Syncs debt to cement unrealised debt. 
         MinCollValue is calculated without unrealised debt since it is zero.
         Gets the total value of assets per credit rating.
         Calculates and sets the yearly interest rate based on the values per credit rating and the debt to be taken out.
         Mints stablecoin to the vault owner.
  */
  function _takeCredit(
    uint128 amount,
    address[] memory _assetAddresses, 
    uint256[] memory _assetIds,
    uint256[] memory _assetAmounts
  ) private {

    syncDebt();

    uint256 minCollValue;
    //gas: can't overflow: uint129 * uint16 << uint256
    unchecked {minCollValue = uint256((uint256(debt._openDebt) + amount) * debt._collThres) / 100;}

    uint256[] memory valuesPerCreditRating = IRegistry(_registryAddress).getListOfValuesPerCreditRating(_assetAddresses, _assetIds, _assetAmounts, debt._numeraire);
    uint256 vaultValue = sumElementsOfList(valuesPerCreditRating);

    require(vaultValue >= minCollValue, "Cannot take this amount of extra credit!" );

    _setYearlyInterestRate(valuesPerCreditRating, minCollValue);

    //gas: can only overflow when total opendebt is
    //above 340 billion billion *10**18 decimals
    //could go unchecked as well, but might result in opendebt = 0 on overflow
    debt._openDebt += amount;
    IERC20(_stable).mint(owner, amount);
  }

  /** 
    @notice Calculates the total open debt on the proxy vault, including unrealised debt.
    @dev Debt is expressed in an uint128 as the stored debt is an uint128 as well.
         _yearlyInterestRate = 1 + r expressed as 18 decimals fixed point number
    @return openDebt Total open debt, as a uint128.
  */
  function getOpenDebt() public view returns (uint128 openDebt) {
    uint128 base;
    uint128 exponent;
    unchecked {
      //gas: can't overflow as long as interest remains < 1744%/yr
      base = uint128(1e18) + debt._yearlyInterestRate;

      //gas: only overflows when blocks.number > ~10**20
      exponent = uint128((block.number - debt._lastBlock) * 1e18 / yearlyBlocks);
    }

    //with sensible blocks, can return an open debt up to 3e38 units
    //gas: could go unchecked as well, but might result in opendebt = 0 on overflow
    openDebt = uint128(debt._openDebt * LogExpMath.pow(base, exponent) / 1e18); 
  }

  /** 
    @notice Calculates the remaining credit the owner of the proxy vault can take out.
    @dev Returns the remaining credit in the numeraire in which the proxy vault is initialised.
    @return remainingCredit The remaining amount of credit a user can take, 
                            returned in the decimals of the stablecoin.
  */
  function getRemainingCredit() public view returns (uint256 remainingCredit) {
    uint256 currentValue = getValue(debt._numeraire);
    uint256 openDebt = getOpenDebt();

    uint256 maxAllowedCredit;
    //gas: cannot overflow unless currentValue is more than
    // 1.15**57 *10**18 decimals, which is too many billions to write out
    unchecked {maxAllowedCredit = (currentValue * 100) / debt._collThres;}

    //gas: explicit check is done to prevent underflow
    unchecked {remainingCredit = maxAllowedCredit > openDebt ? maxAllowedCredit - openDebt : 0;}
  }

  /** 
    @notice Function used by owner of the proxy vault to repay any open debt.
    @dev Amount of debt to repay in same decimals as the stablecoin decimals.
         Amount given can be greater than open debt. Will only transfer the required
         amount from the user's balance.
    @param amount Amount of debt to repay.
  */
  function repayDebt(uint256 amount) public onlyOwner {
    syncDebt();

    // if a user wants to pay more than their open debt
    // we should only take the amount that's needed
    // prevents refunds etc
    uint256 openDebt = debt._openDebt;
    uint256 transferAmount = openDebt > amount ? amount : openDebt;
    require(IERC20(_stable).transferFrom(msg.sender, address(this), transferAmount), "Transfer from failed");

    IERC20(_stable).burn(transferAmount);

    //gas: transferAmount cannot be larger than debt._openDebt,
    //which is a uint128, thus can't underflow
    assert(openDebt >= transferAmount);
    unchecked {debt._openDebt -= uint128(transferAmount);}

    // if interest is calculated on a fixed rate, set interest to zero if opendebt is zero
    // todo: can be removed safely?
    if (getOpenDebt() == 0) {
      debt._yearlyInterestRate = 0;
    }

  }

  /** 
    @notice Function called to start a vault liquidation.
    @dev Requires an unhealthy vault (value / debt < liqThres).
         Starts the vault auction on the liquidator contract.
         Increases the life of the vault to indicate a liquidation has happened.
         Sets debtInfo todo: needed?
         Transfers ownership of the proxy vault to the liquidator!
  */
  function liquidateVault(address liquidationKeeper, address liquidator) public onlyFactory returns (bool success) {
    //gas: 35 gas cheaper to not take debt into memory
    uint256 totalValue = getValue(debt._numeraire);
    uint256 leftHand;
    uint256 rightHand;

    unchecked {
      //gas: cannot overflow unless totalValue is
      //higher than 1.15 * 10**57 * 10**18 decimals
      leftHand = totalValue * 100;
      //gas: cannot overflow: uint8 * uint128 << uint256
      rightHand = uint256(debt._liqThres) * uint256(debt._openDebt); //yes, double cast is cheaper than no cast (and equal to one cast)
    }

    require(leftHand < rightHand, "This vault is healthy");

    
    require(ILiquidator(liquidator).startAuction(address(this), life, liquidationKeeper, owner, debt._openDebt, debt._liqThres), "Failed to start auction!");

    //gas: good luck overflowing this
    unchecked {++life;}

    debt._openDebt = 0;
    debt._lastBlock = 0;

    return true;
    }

  function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
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
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "./../Vault.sol";
////import {FixedPointMathLib} from './../utils/FixedPointMathLib.sol';

contract VaultPaperTrading is Vault {
  using FixedPointMathLib for uint256;

  address public _tokenShop;

  constructor() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any address other than the tokenshop
   *  only added for the paper trading competition
   */
  modifier onlyTokenShop() {
    require(msg.sender == _tokenShop, "Not tokenshop");
    _;
  }

  function initialize(address, address, address, address, address) external payable override {
   revert('Not Allowed');
  }

  /** 
    @notice Initiates the variables of the vault
    @dev A proxy will be used to interact with the vault logic.
         Therefore everything is initialised through an init function.
         This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
         Costly function (156k gas)
    @param _owner The tx.origin: the sender of the 'createVault' on the factory
    @param registryAddress The 'beacon' contract to which should be looked at for external logic.
    @param stable The contract address of the stablecoin of Arcadia Finance
    @param stakeContract The stake contract in which stablecoin can be staked. 
                         Used when syncing debt: interest in stable is minted to stakecontract.
    @param irmAddress The contract address of the InterestRateModule, which calculates the going interest rate
                      for a credit line, based on the underlying assets.
    @param tokenShop The contract with the mocked token shop, added for the paper trading competition
  */
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address irmAddress, address tokenShop) external payable {
    require(initialized == false);
    _registryAddress = registryAddress;
    owner = _owner;
    debt._collThres = 150;
    debt._liqThres = 110;
    _stable = stable;
    _stakeContract = stakeContract;
    _irmAddress = irmAddress;
    _tokenShop = tokenShop; //Variable only added for the paper trading competition

    initialized = true;

    //Following logic added only for the paper trading competition
    //All new vaults are initiated with $1.000.000
    address[] memory addressArr = new address[](1);
    uint256[] memory idArr = new uint256[](1);
    uint256[] memory amountArr = new uint256[](1);

    addressArr[0] = _stable;
    idArr[0] = 0;
    amountArr[0] = FixedPointMathLib.WAD;

    uint256 rateStableToUsd = IRegistry(_registryAddress).getTotalValue(addressArr, idArr, amountArr, 0);
    uint256 stableAmount = FixedPointMathLib.mulDivUp(1000000 * FixedPointMathLib.WAD, FixedPointMathLib.WAD, rateStableToUsd);
    IERC20(_stable).mint(address(this), stableAmount);
    super._depositERC20(address(this), _stable, stableAmount);
  }

  /** 
    @notice The function used to deposit assets into the proxy vault by the proxy vault owner.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get deposited. If multiple asset IDs of the same contract address
         are deposited, the assetAddress must be repeated in assetAddresses.
         The ERC20 get deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner to avoid attacks where malicous actors can deposit 1 wei assets,
         increasing gas costs upon credit issuance and withrawals.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be deposited one address,
                          even if multiple assets of the same contract address are deposited.
    @param assetIds The asset IDs that will be deposited for ERC721 & ERC1155. 
                    When depositing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be deposited. 
    @param assetTypes The types of the assets to be deposited.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable override onlyTokenShop {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    

    require(IRegistry(_registryAddress).batchIsWhiteListed(assetAddresses, assetIds), "Not all assets are whitelisted!");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        super._depositERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        super._depositERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        super._depositERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  /** 
    @notice Processes withdrawals of assets by and to the owner of the proxy vault.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
         are to be withdrawn, the assetAddress must be repeated in assetAddresses.
         The ERC20 get withdrawn by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner.
         Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
         Will fail if "the value after withdrawal / open debt (including unrealised debt) > collateral threshold".
         If no debt is taken yet on this proxy vault, users are free to withraw any asset at any time.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be withdrawn one address,
                          even if multiple assets of the same contract address are withdrawn.
    @param assetIds The asset IDs that will be withdrawn for ERC721 & ERC1155. 
                    When withdrawing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be withdrawn. 
    @param assetTypes The types of the assets to be withdrawn.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable override onlyTokenShop {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        super._withdrawERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        super._withdrawERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        super._withdrawERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

    uint256 openDebt = getOpenDebt();
    if (openDebt != 0) {
      require((getValue(debt._numeraire) * 100 / openDebt) > debt._collThres , "Cannot withdraw since the collateral value would become too low!" );
    }

  }

}



/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/
            
// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

////import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/** 
  * @title Interest Rate Module
  * @author Arcadia Finance
  * @notice The Interest Rate Module manages the base interest rate and the collateral specific interest rates
  * @dev No end-user should directly interact with the Interest Rate Module, only the Main-registry or the contract owner
 */
contract InterestRateModule is Ownable {

  uint256 public baseInterestRate;

  mapping (uint256 => uint256) public creditRatingToInterestRate;

  /**
   * @notice Constructor
   */
  constructor() {
  }

  /**
   * @notice Sets the base interest rate (cost of capital)
   * @param _baseInterestRate The new base interest rate (yearly APY)
   * @dev The base interest rate is standard initialized as 0
   *  the base interest rate is the relative compounded interest after one year, it is an integer with 18 decimals
   *  Example: For a yearly base interest rate of 2% APY, _baseInterestRate must equal 20 000 000 000 000 000
   */
	function setBaseInterestRate(uint64 _baseInterestRate) external onlyOwner {
		baseInterestRate = _baseInterestRate;
	}

  /**
   * @notice Sets interest rate for Credit Rating Categories (risk associated with collateral)
   * @param creditRatings The list of indices of the Credit Rating Categories for which the Interest Rate needs to be changed
   * @param interestRates The list of new interest rates (yearly APY) for the corresponding Credit Rating Categories
   * @dev The Credit Rating Categories are standard initialized with 0
   *  the interest rates are relative compounded interests after one year, it are integers with 18 decimals
   *  Example: For a yearly interest rate of 2% APY, _baseInterestRate must equal 20 000 000 000 000 000
   *  Each Credit Rating Category is labeled with an integer, Category 0 (the default) is for the most risky assets
   *  hence it will have the highest interest rate. Each Category from 1 to 10 will be used to label groups of assets
   *  with similart risk profiles (Comparable to ratings like AAA, A-, B... for debtors in traditional finance).
   */
  function batchSetCollateralInterestRates(uint256[] calldata creditRatings, uint256[] calldata interestRates) external onlyOwner {
    uint256 creditRatingsLength = creditRatings.length;
    require(creditRatingsLength == interestRates.length, 'IRM: LENGTH_MISMATCH');
    for (uint256 i; i < creditRatingsLength;) {
      creditRatingToInterestRate[creditRatings[i]] = interestRates[i];
      unchecked {++i;}
    }
  }

  /**
   * @notice Returns the weighted interest rate of a basket of different assets depending on their Credit rating category
   * @param valuesPerCreditRating A list of the values (denominated in a single Numeraire) of assets per Credit Rating Category
   * @param minCollValue The minimal collaterisation value (denominated in the same Numeraire)
   * @return collateralInterestRate The weighted asset specific interest rate of a basket of assets
   * @dev Since each Credit Rating Category has its own specific interest rate, the interest rate for a basket of collateral
   *  is calculated as the weighted interest rate over the different Credit Rating Categories.
   *  The function will start from the highest quality Credit Rating Category (labeled as 1) check if the value of Category 1 exceeds
   *  a certain treshhold, the minimal collaterisation value. If not it goes to the second best category(labeled as 2) and so forth.
   *  If the treshhold is not reached after category 10, the remainder of value to meet the minimal collaterisation value is
   *  assumed to be of the worst category (labeled as 0).
   */
  function calculateWeightedCollateralInterestrate(uint256[] memory valuesPerCreditRating, uint256 minCollValue) internal view returns (uint256) {
    if (minCollValue == 0) {
      return 0;
    } else {
      uint256 collateralInterestRate;
      uint256 totalValue;
      uint256 value;
      uint256 valuesPerCreditRatingLength = valuesPerCreditRating.length;
      for (uint256 i = 1; i < valuesPerCreditRatingLength;) {
        value = valuesPerCreditRating[i];
        if (totalValue + value < minCollValue) {
          collateralInterestRate += creditRatingToInterestRate[i] * value / minCollValue;
          totalValue += value;
        } else {
          value = minCollValue - totalValue;
          collateralInterestRate += creditRatingToInterestRate[i] * value / minCollValue;
          return collateralInterestRate;
        }
        unchecked {++i;}
      }
      //Loop ended without returning -> use lowest credit rating (at index 0) for remaining collateral
      value = minCollValue - totalValue;
      collateralInterestRate += creditRatingToInterestRate[0] * value / minCollValue;

      return collateralInterestRate;
    }
  }

  /**
   * @notice Returns the interest rate of a basket of different assets
   * @param valuesPerCreditRating A list of the values (denominated in a single Numeraire) of assets per Credit Rating Category
   * @param minCollValue The minimal collaterisation value (denominated in the same Numeraire)
   * @return yearlyInterestRate The total yearly compounded interest rate of of a basket of assets
   * @dev The yearly interest rate exists out of a base rate (cost of capital) and a collatereal specific rate (price risks of collateral)
   *  The interest rate is the relative compounded interest after one year, it is an integer with 18 decimals
   *  Example: For a yearly interest rate of 2% APY, yearlyInterestRate will equal 20 000 000 000 000 000
   */
	function getYearlyInterestRate(uint256[] calldata valuesPerCreditRating, uint256 minCollValue) external view returns (uint64 yearlyInterestRate) {
    //ToDo: checks on min and max length to implement
		yearlyInterestRate =  uint64(baseInterestRate) + uint64(calculateWeightedCollateralInterestrate(valuesPerCreditRating, minCollValue));
	}
  
}


/** 
 *  SourceUnit: c:\Users\Jasper\Documents\ArcadiaFinanceCore\lending-core\src\paperTradingCompetition\Deploy\contracts\Deploy_four.sol
*/

////// SPDX-License-Identifier-FLATTEN-SUPPRESS-WARNING: UNLICENSED
pragma solidity >0.8.10;

////import "../../../InterestRateModule.sol";
////import "../../VaultPaperTrading.sol";

contract DeployContractsFour  {
  
  InterestRateModule public interestRateModule;
  VaultPaperTrading public vault;
  VaultPaperTrading public proxy;
  address public proxyAddr;
  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function deployIRM() external returns (address) {
    InterestRateModule irm = new InterestRateModule();
    irm.transferOwnership(msg.sender);
    return address(irm);
  }

  function deployVaultLogic() external returns (address) {
    VaultPaperTrading vaultLog = new VaultPaperTrading();
    return address(vaultLog);
  }

  
}

