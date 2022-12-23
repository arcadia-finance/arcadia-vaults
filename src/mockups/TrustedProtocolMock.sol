/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {TrustedProtocol} from "../../lib/arcadia-lending/src/TrustedProtocol.sol";

contract TrustedProtocolMock is TrustedProtocol {
    constructor() TrustedProtocol() {}

    function openMarginAccount()
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
