/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0;

interface IUniswapV2Factory {
    function feeTo() external view returns (address);
}
