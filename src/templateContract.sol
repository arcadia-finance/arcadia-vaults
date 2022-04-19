// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

contract templateContract {
  address public exampleAddress;
  uint256 public exampleNumber;

  constructor (address addr, uint256 number) {
    exampleAddress = addr;
    exampleNumber = number;
  }

  function testInput() view public {
    require(exampleNumber < 1, "input too large");
  }

  function storeInput(uint256 input) public {
    exampleNumber = input;
  }

}
