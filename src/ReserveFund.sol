// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IStable.sol";

contract ReserveFund {

  address public owner;
  address public liquidator;

  modifier onlyOwnerOrLiquidator() {
    require(msg.sender == owner || msg.sender == liquidator);
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  constructor () {
    owner = msg.sender;
  }

  function setLiquidator(address newLiquidator) external onlyOwner {
    liquidator = newLiquidator;
  }


  function withdraw(uint256 amount, address tokenAddress, address to) external onlyOwnerOrLiquidator returns (bool){
    require(IStable(tokenAddress).transfer(to, amount), "RF: transfer failed");
    
    return true;
  }
}