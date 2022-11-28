/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity >=0.4.22 <0.9.0;

interface IUniswapV2Factory {
    function feeTo() external view returns (address);
}
