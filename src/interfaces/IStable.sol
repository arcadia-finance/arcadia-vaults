// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IStable {
    function safeBurn(address from, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);
}
