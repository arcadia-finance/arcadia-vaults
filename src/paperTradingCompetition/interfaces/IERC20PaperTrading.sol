/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IERC20.sol";

interface IERC20PaperTrading is IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}
