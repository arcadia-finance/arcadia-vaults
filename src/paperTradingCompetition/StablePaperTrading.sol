// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../Stable.sol";

contract StablePaperTrading is Stable {

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address liquidatorAddress, address _factory) Stable(name, symbol, _decimalsInput, liquidatorAddress, _factory) {}

  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    if (from == to) {
      return true; 
    } else {
      return super.transferFrom(from, to, amount);
    }
  }

}