// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../lib/solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {


  constructor(string memory name, string memory symbol, uint8 _decimalsInput) ERC20(name, symbol, _decimalsInput) {
  }

  function mint(address to, uint256 amount) public {
      _mint(to, amount);
  }

  function burn(uint256 amount) public {
      _burn(msg.sender, amount);
  }

  //Following logic added only for the paper trading competition
  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    if (from == to) {
      return true; 
    } else {
      return super.transferFrom(from, to, amount);
    }
  }

}
