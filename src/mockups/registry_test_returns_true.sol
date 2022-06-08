/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialization, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.8;

contract Registry {
    mapping(address => bool) whitelisted;
    uint256 public returnValue = 10000;

    function batchIsWhiteListed(
        address[] calldata assetAddresses,
        uint256[] calldata
    ) external view returns (bool) {
        for (uint256 i; i < assetAddresses.length; i++) {
            if (!whitelisted[assetAddresses[i]]) {
                return false;
            }
        }
        return true;
    }

    function changeReturnValue(uint256 newValue) public {
        returnValue = newValue;
    }

    function whitelist(address erc20addr, bool status) public {
        whitelisted[erc20addr] = status;
    }

    function getValue(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        string calldata
    ) public view returns (uint256) {
        return returnValue;
    }
}
