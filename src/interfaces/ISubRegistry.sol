/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialisation, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

interface ISubRegistry {
    struct GetValueInput {
        address assetAddress;
        uint256 assetId;
        uint256 assetAmount;
        uint256 numeraire;
    }

    function isAssetAddressWhiteListed(address) external view returns (bool);

    function isWhiteListed(address, uint256) external view returns (bool);

    function getValue(GetValueInput memory)
        external
        view
        returns (uint256, uint256);
}
