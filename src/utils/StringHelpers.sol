// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library StringHelpers {
    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(bytes(a)) == keccak256(bytes(b));
        }
    }
}
