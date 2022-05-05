// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./mockups/ERC20SolmateMock.sol";
import "./interfaces/IFactory.sol";

contract Stable is ERC20 {

  address public liquidator;
  address public owner;
  address public factory;

  modifier onlyOwner {
      require(msg.sender == owner, "You are not the owner");
      _;
  }

  modifier onlyVault {
      require(IFactory(factory).isVault(msg.sender), "Only a vault can mint!");
      _;
  }

  constructor(string memory name, string memory symbol, uint8 _decimalsInput, address liquidatorAddress, address _factory) ERC20(name, symbol, _decimalsInput) {
      liquidator = liquidatorAddress;
      owner = msg.sender;
      factory = _factory;
  }

  function setFactory(address _factory) public onlyOwner {
      factory = _factory;
  }

  function mint(address to, uint256 amount) public onlyVault {
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

//Following logic added only for the paper trading competition
  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    if (from == to) {
      return true; 
    } else {
      return super.transferFrom(from, to, amount);
    }
  }
}
