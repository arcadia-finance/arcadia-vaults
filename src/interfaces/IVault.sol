/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
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
