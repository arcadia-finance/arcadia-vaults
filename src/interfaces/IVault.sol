/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialization, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

interface IVault {
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function initialize(
        address _owner,
        address registryAddress,
        uint256 numeraire,
        address stable,
        address stakeContract,
        address interestModule
    ) external;

    function liquidateVault(address liquidationKeeper, address liquidator)
        external
        returns (bool);
}
