// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IERC721 {
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function ownerOf(uint256 tokenId) external view returns (address owner);
  function mint(address to, uint256 id) external; //function only added for the paper trading competition
  function burn(uint256 id) external; //function only added for the paper trading competition
}