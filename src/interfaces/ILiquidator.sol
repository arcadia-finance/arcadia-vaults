/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface ILiquidator {
    function startAuction(
        address vaultAddress,
        uint256 life,
        address liquidationKeeper,
        address originalOwner,
        uint128 openDebt,
        uint8 liqThres,
        uint8 numeraire
    ) external returns (bool);
}
