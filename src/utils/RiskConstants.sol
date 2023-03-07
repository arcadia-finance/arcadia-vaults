/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

pragma solidity ^0.8.13;

library RiskConstants {
    // Math
    uint16 public constant RISK_VARIABLES_UNIT = 100;

    uint16 public constant MIN_COLLATERAL_FACTOR = 0;
    uint16 public constant MIN_LIQUIDATION_FACTOR = 0;

    uint16 public constant MAX_COLLATERAL_FACTOR = 100;
    uint16 public constant MAX_LIQUIDATION_FACTOR = 100;

    uint16 public constant DEFAULT_COLLATERAL_FACTOR = 50;
    uint16 public constant DEFAULT_LIQUIDATION_FACTOR = 90;
}
