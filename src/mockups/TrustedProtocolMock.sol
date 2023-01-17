/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {TrustedProtocol} from "../../lib/arcadia-lending/src/TrustedProtocol.sol";

contract TrustedProtocolMock is TrustedProtocol {
    uint256 public openPosition_;

    constructor() TrustedProtocol() {}

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

    function getOpenPosition(address) external view override returns (uint256 openPosition) {
        openPosition = openPosition_;
    }

    function setOpenPosition(uint256 openPosition) public {
        openPosition_ = openPosition;
    }
}
