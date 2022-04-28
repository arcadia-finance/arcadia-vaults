// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./ERC20SolmateNoApprove.sol";

contract ERC20NoApprove is ERC20 {


  constructor(uint8 _decimalsInput) ERC20("No approve", "No approve", _decimalsInput) {
  }

  function mint(address to, uint256 amount) public {
      _mint(to, amount);
  }

//   function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) public returns (bool) {
//         return super.transferFrom(from, to, amount);
//     }

  function burn(uint256 amount) public {
      _burn(msg.sender, amount);
  }

}
