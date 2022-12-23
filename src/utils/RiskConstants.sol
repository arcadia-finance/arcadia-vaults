/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

pragma solidity ^0.8.0;

library RiskConstants {
    // Math
    uint16 public constant RISK_VARIABLES_UNIT = 100;

    uint16 public constant MIN_COLLATERAL_FACTOR = 0;
    uint16 public constant MIN_LIQUIDATION_THRESHOLD = 100;

    uint16 public constant MAX_COLLATERAL_FACTOR = 100;
    uint16 public constant MAX_LIQUIDATION_THRESHOLD = 10000;

    uint16 public constant DEFAULT_COLLATERAL_FACTOR = 50;
    uint16 public constant DEFAULT_LIQUIDATION_THRESHOLD = 110;
}
