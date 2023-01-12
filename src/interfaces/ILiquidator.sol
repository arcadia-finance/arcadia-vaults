/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface ILiquidator {
    function startAuction(
        uint256 life,
        address liquidationInitiator,
        address originalOwner,
        uint128 openDebt,
        address baseCurrency,
        address trustedCreditor
    ) external returns (bool);
}
