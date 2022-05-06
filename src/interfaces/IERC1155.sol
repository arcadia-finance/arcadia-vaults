// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC1155 {
  function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
  function mint(address to, uint256 id, uint256 amount) external; //function only added for the paper trading competition
  function burn(uint256 id, uint256 amount) external; //function only added for the paper trading competition
  }