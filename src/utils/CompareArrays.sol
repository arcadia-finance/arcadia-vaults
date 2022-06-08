// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library CompareArrays {
    function compareArrays(address[] memory arr1, address[] memory arr2)
        public
        pure
        returns (bool)
    {
        if (arr1.length != arr2.length) {
            return false;
        }
        for (uint256 i; i < arr1.length; i++) {
            if (arr1[i] != arr2[i]) {
                return false;
            }
        }
        return true;
    }

    function compareArrays(uint256[] memory arr1, uint256[] memory arr2)
        public
        pure
        returns (bool)
    {
        if (arr1.length != arr2.length) {
            return false;
        }
        for (uint256 i; i < arr1.length; i++) {
            if (arr1[i] != arr2[i]) {
                return false;
            }
        }
        return true;
    }
}
