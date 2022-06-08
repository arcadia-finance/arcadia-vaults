// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

contract impl {
    uint256 public valuestored;
    address public initvalue;
    string public stringinput;

    constructor(address inputaddr) {
        initvalue = inputaddr;
    }

    function returnOne(uint256 val) public returns (uint256) {
        valuestored = val;
        return valuestored;
    }

    function verifyOne(uint256) public view returns (bool) {
        require(valuestored == 1, "error not the value");
        return true;
    }
}
