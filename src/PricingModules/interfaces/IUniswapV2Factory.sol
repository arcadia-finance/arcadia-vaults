/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IUniswapV2Factory {
    function feeTo() external view returns (address);
}
