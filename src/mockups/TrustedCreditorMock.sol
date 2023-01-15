/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {TrustedCreditor} from "../../lib/arcadia-lending/src/TrustedCreditor.sol";

contract TrustedCreditorMock is TrustedCreditor {
    bool isCallSuccesfull;

    address baseCurrency;
    address liquidator;

    mapping(address => uint256) openPosition;

    constructor() TrustedCreditor() {}

    function liquidateVault(uint256) public override {}

    function openMarginAccount(uint256)
        external
        view
        override
        returns (bool success, address baseCurrency_, address liquidator_)
    {
        if (isCallSuccesfull) {
            success = true;
            baseCurrency_ = baseCurrency;
            liquidator_ = liquidator;
        } else {
            success = false;
            baseCurrency_ = address(0);
            liquidator_ = address(0);
        }
    }

    function getOpenPosition(address vault) external view override returns (uint256 openPosition_) {
        openPosition_ = openPosition[vault];
    }

    function setOpenPosition(address vault, uint256 openPosition_) external {
        openPosition[vault] = openPosition_;
    }

    function setCallResult(bool success) external {
        isCallSuccesfull = success;
    }

    function setBaseCurrency(address baseCurrency_) external {
        baseCurrency = baseCurrency_;
    }

    function setLiquidator(address liquidator_) external {
        liquidator = liquidator_;
    }
}
