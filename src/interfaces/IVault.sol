// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

interface IVault {
  function owner() external view returns (address);
  function transferOwnership(address newOwner) external;
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address interestModule, address tokenShop) external; //tokenShop only added for the paper trading competition
  function liquidateVault(address liquidationKeeper, address liquidator) external returns (bool);
  function debt() external returns(uint128 _openDebt, uint16 _collThres, uint8 _liqThres, uint64 _yearlyInterestRate, uint32 _lastBlock, uint8 _numeraire);
}