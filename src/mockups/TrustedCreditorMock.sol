/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {TrustedCreditor} from "../../lib/arcadia-lending/src/TrustedCreditor.sol";

contract TrustedCreditorMock is TrustedCreditor {
    constructor() TrustedCreditor() {}

    function liquidateVault(address, uint256) public override {}

    function openMarginAccount(uint256)
        external
        pure
        override
        returns (bool success, address baseCurrency, address liquidator_)
    {
        success = false;
        baseCurrency = address(0);
        liquidator_ = address(0);
    }

    function getOpenPosition(address) external pure override returns (uint256 openPosition) {
        openPosition = 0;
    }
}
