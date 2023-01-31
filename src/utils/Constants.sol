/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

pragma solidity ^0.8.0;

library Constants {
    // Math
    uint256 internal constant UsdBaseCurrency = 0;
    uint256 internal constant DaiBaseCurrency = 1;
    uint256 internal constant EthBaseCurrency = 2;
    uint256 internal constant SafemoonBaseCurrency = 3;

    uint256 internal constant usdDecimals = 18;
    uint256 internal constant daiDecimals = 12;
    uint256 internal constant ethDecimals = 13;

    uint256 internal constant ethCreditRatingUsd = 2;
    uint256 internal constant ethCreditRatingBtc = 0;
    uint256 internal constant ethCreditRatingEth = 1;
    uint256 internal constant ethCreditRatingDai = 1;
    uint256 internal constant snxDecimals = 14;
    uint256 internal constant snxCreditRatingUsd = 0;
    uint256 internal constant snxCreditRatingEth = 0;
    uint256 internal constant snxCreditRatingDai = 0;
    uint256 internal constant linkDecimals = 4;
    uint256 internal constant linkCreditRatingUsd = 2;
    uint256 internal constant linkCreditRatingEth = 2;
    uint256 internal constant linkCreditRatingDai = 2;
    uint256 internal constant safemoonDecimals = 18;
    uint256 internal constant safemoonCreditRatingUsd = 0;
    uint256 internal constant safemoonCreditRatingEth = 0;
    uint256 internal constant safemoonCreditRatingDai = 0;
    uint256 internal constant baycCreditRatingUsd = 4;
    uint256 internal constant baycCreditRatingEth = 3;
    uint256 internal constant baycCreditRatingDai = 3;
    uint256 internal constant maycCreditRatingUsd = 0;
    uint256 internal constant maycCreditRatingEth = 0;
    uint256 internal constant maycCreditRatingDai = 0;
    uint256 internal constant dickButsCreditRatingUsd = 0;
    uint256 internal constant dickButsCreditRatingEth = 0;
    uint256 internal constant dickButsCreditRatingDai = 0;
    uint256 internal constant interleaveCreditRatingUsd = 0;
    uint256 internal constant interleaveCreditRatingEth = 0;
    uint256 internal constant interleaveCreditRatingDai = 0;
    uint256 internal constant wbaycDecimals = 16;
    uint256 internal constant wmaycDecimals = 14;

    uint256 internal constant oracleDaiToUsdDecimals = 18;
    uint256 internal constant oracleEthToUsdDecimals = 8;
    uint256 internal constant oracleLinkToUsdDecimals = 8;
    uint256 internal constant oracleSnxToEthDecimals = 18;
    uint256 internal constant oracleSafemoonToUsdDecimals = 18;
    uint256 internal constant oracleWbaycToEthDecimals = 18;
    uint256 internal constant oracleWmaycToUsdDecimals = 8;
    uint256 internal constant oracleInterleaveToEthDecimals = 10;

    uint256 internal constant oracleDaiToUsdUnit = 10 ** oracleDaiToUsdDecimals;
    uint256 internal constant oracleEthToUsdUnit = 10 ** oracleEthToUsdDecimals;
    uint256 internal constant oracleLinkToUsdUnit = 10 ** oracleLinkToUsdDecimals;
    uint256 internal constant oracleSnxToEthUnit = 10 ** oracleSnxToEthDecimals;
    uint256 internal constant oracleSafemoonToUsdUnit = 10 ** oracleSafemoonToUsdDecimals;
    uint256 internal constant oracleWbaycToEthUnit = 10 ** oracleWbaycToEthDecimals;
    uint256 internal constant oracleWmaycToUsdUnit = 10 ** oracleWmaycToUsdDecimals;
    uint256 internal constant oracleInterleaveToEthUnit = 10 ** oracleInterleaveToEthDecimals;

    uint256 internal constant assetDecimals = 18;

    uint256 internal constant WAD = 1e18;

    // see src\test\MerkleTrees
    bytes32 internal constant upgradeProof1To2 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant upgradeRoot1To3 = 0x4a4a80da24004c581ecd9b9f53cb47269f979e9a0271f115ac01b91bd35349aa;
    bytes32 internal constant upgradeRoot1To2 = 0x472ba66bf173e177005d95fe17be2002ac4c417ff5bef6fb20a1e357f75bf394;
    bytes32 internal constant upgradeRoot1To1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;

    uint72 internal constant interestRate = 5e16; //5% with 18 decimals precision
    uint40 internal constant utilisationThreshold = 8e4; //80% with 5 decimals precision
}
