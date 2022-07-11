/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IVault.sol";

interface IVaultPaperTrading is IVault {
    function _stable() external view returns (address);

    function initialize(
        address _owner,
        address registryAddress,
        uint256 numeraire,
        address stable,
        address stakeContract,
        address interestModule,
        address tokenShop
    ) external;

    function debt()
        external
        view
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

    function withdrawERC20(address assetAddress, uint256 assetAmount) external;

    function deposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external;

    function depositERC20(address assetAddress, uint256 assetAmount) external;

    function receiveReward() external;

    function life() external view returns (uint256);

    function getValue(uint8) external view returns (uint256);

    function setYearlyInterestRate() external;
}
