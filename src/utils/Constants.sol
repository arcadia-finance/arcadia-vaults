/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */

pragma solidity ^0.8.0;

library Constants {
    // Math
    uint256 internal constant UsdNumeraire = 0;
    uint256 internal constant EthNumeraire = 1;
    uint256 internal constant SafemoonNumeraire = 2;

    uint256 internal constant ethDecimals = 12;
    uint256 internal constant ethCreditRatingUsd = 2;
    uint256 internal constant ethCreditRatingBtc = 0;
    uint256 internal constant ethCreditRatingEth = 1;
    uint256 internal constant snxDecimals = 14;
    uint256 internal constant snxCreditRatingUsd = 0;
    uint256 internal constant snxCreditRatingEth = 0;
    uint256 internal constant linkDecimals = 4;
    uint256 internal constant linkCreditRatingUsd = 2;
    uint256 internal constant linkCreditRatingEth = 2;
    uint256 internal constant safemoonDecimals = 18;
    uint256 internal constant safemoonCreditRatingUsd = 0;
    uint256 internal constant safemoonCreditRatingEth = 0;
    uint256 internal constant baycCreditRatingUsd = 4;
    uint256 internal constant baycCreditRatingEth = 3;
    uint256 internal constant maycCreditRatingUsd = 0;
    uint256 internal constant maycCreditRatingEth = 0;
    uint256 internal constant dickButsCreditRatingUsd = 0;
    uint256 internal constant dickButsCreditRatingEth = 0;
    uint256 internal constant interleaveCreditRatingUsd = 0;
    uint256 internal constant interleaveCreditRatingEth = 0;
    uint256 internal constant wbaycDecimals = 16;
    uint256 internal constant wmaycDecimals = 14;

    uint256 internal constant oracleEthToUsdDecimals = 8;
    uint256 internal constant oracleLinkToUsdDecimals = 8;
    uint256 internal constant oracleSnxToEthDecimals = 18;
    uint256 internal constant oracleWbaycToEthDecimals = 18;
    uint256 internal constant oracleWmaycToUsdDecimals = 8;
    uint256 internal constant oracleInterleaveToEthDecimals = 10;
    uint256 internal constant oracleStableToUsdDecimals = 12;
    uint256 internal constant oracleStableEthToEthDecimals = 14;

    uint256 internal constant oracleEthToUsdUnit = 10**oracleEthToUsdDecimals;
    uint256 internal constant oracleLinkToUsdUnit = 10**oracleLinkToUsdDecimals;
    uint256 internal constant oracleSnxToEthUnit = 10**oracleSnxToEthDecimals;
    uint256 internal constant oracleWbaycToEthUnit =
        10**oracleWbaycToEthDecimals;
    uint256 internal constant oracleWmaycToUsdUnit =
        10**oracleWmaycToUsdDecimals;
    uint256 internal constant oracleInterleaveToEthUnit =
        10**oracleInterleaveToEthDecimals;
    uint256 internal constant oracleStableToUsdUnit =
        10**oracleStableToUsdDecimals;
    uint256 internal constant oracleStableEthToEthUnit =
        10**oracleStableEthToEthDecimals;

    uint256 internal constant usdDecimals = 14;
    uint256 internal constant stableDecimals = 18;
    uint256 internal constant stableEthDecimals = 18;

    uint256 internal constant WAD = 1e18;
}
