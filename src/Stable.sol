// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./mockups/ERC20SolmateMock.sol";

contract Stable is ERC20 {

  address public liquidator;
  address public owner;

  modifier onlyOwner {
      require(msg.sender == owner, "You are not the owner");
      _;
  }

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address liquidatorAddress) ERC20(name, symbol, _decimalsInput) {
      liquidator = liquidatorAddress;
      owner = msg.sender;
  }

  function mint(address to, uint256 amount) public {
      _mint(to, amount);
  }

  function setLiquidator(address liq) public onlyOwner {
      liquidator = liq;
  }

  function burn(uint256 amount) public {
      _burn(msg.sender, amount);
  }
function safeBurn(address from, uint256 amount) public returns (bool) {
    require(msg.sender == from || msg.sender == liquidator);
    _burn(from, amount);

    return true;
  }

}
