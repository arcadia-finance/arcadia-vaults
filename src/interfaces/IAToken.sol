/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
 
pragma solidity >=0.4.22 <0.9.0;

import {IERC20} from './IERC20.sol';
import {IScaledBalanceToken} from './IScaledBalanceToken.sol';

interface IAToken is IScaledBalanceToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}