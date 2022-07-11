/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface ITokenShop {
    function _stable() external view returns (address);

    function initialize(
        address _owner,
        address registryAddress,
        address stable,
        address stakeContract,
        address interestModule,
        address tokenShop
    ) external;

    function debt()
        external
        returns (
            uint128 _openDebt,
            uint16 _collThres,
            uint8 _liqThres,
            uint64 _yearlyInterestRate,
            uint32 _lastBlock,
            uint8 _numeraire
        );

    function withdraw(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external;

    function deposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external;
}
