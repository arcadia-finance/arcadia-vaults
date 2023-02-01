// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library ArrayHelpers {
    // https://twitter.com/0x_beans/status/1502420621250105346
    /**
     * @notice Returns the sum of all uints in an array.
     * @param _data An uint256 array.
     * @return sum The combined sum of uints in the array.
     */
    function sumElementsOfArray(uint256[] memory _data) public pure returns (uint256 sum) {
        //cache
        uint256 len = _data.length;

        for (uint256 i = 0; i < len;) {
            // optimizooooor
            assembly {
                sum := add(sum, mload(add(add(_data, 0x20), mul(i, 0x20))))
            }

            unchecked {
                ++i;
            }
        }
    }
}
