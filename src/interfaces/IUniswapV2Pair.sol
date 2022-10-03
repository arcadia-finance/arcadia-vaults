/**
 * This is a private, unpublished repository.
 * All rights reserved to Arcadia Finance.
 * Any modification, publication, reproduction, commercialization, incorporation,
 * sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
 *
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

interface IUniswapV2Pair {
    function totalSupply() external view returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function kLast() external view returns (uint256);

    function initialize(address _token0, address _token1) external;
}
