/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

library DeployAddresses {
    address public constant dai = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address public constant eth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address public constant link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address public constant snx = 0x51f44ca59b867E005e48FA573Cb8df83FC7f7597;
    address public constant usdc = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address public constant btc = 0xC04B0d3107736C32e19F1c62b2aF67BE61d63a05;

    address public constant oracleDaiToUsd = 0x0d79df66BE487753B02D015Fb622DED7f0E9798d;
    address public constant oracleEthToUsd = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address public constant oracleLinkToEth = 0xb4c4a493AB6356497713A78FFA6c60FB53517c63;
    address public constant oracleSnxToUsd = 0xdC5f59e61e51b90264b38F0202156F07956E2577;
    address public constant oracleUsdcToUsd = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7;
    address public constant oracleBtcToEth = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
}

library DeployNumbers {
    uint256 public constant oracleDaiToUsdUnit = 1e8;
    uint256 public constant oracleEthToUsdUnit = 1e8;
    uint256 public constant oracleLinkToEthUnit = 1e18;
    uint256 public constant oracleSnxToUsdUnit = 1e8;
    uint256 public constant oracleUsdcToUsdUnit = 1e8;
    uint256 public constant oracleBtcToEthUnit = 1e18;

    uint256 public constant usdDecimals = 18;
    uint256 public constant daiDecimals = 18;
    uint256 public constant ethDecimals = 18;
    uint256 public constant linkDecimals = 18;
    uint256 public constant snxDecimals = 18;
    uint256 public constant usdcDecimals = 6;
    uint256 public constant btcDecimals = 8;

    uint256 public constant UsdBaseCurrency = 0;
    uint256 public constant EthBaseCurrency = 1;
    uint256 public constant UsdcBaseCurrency = 2;
}

library DeployBytes {
    bytes32 public constant upgradeRoot1To2 = 0x472ba66bf173e177005d95fe17be2002ac4c417ff5bef6fb20a1e357f75bf394;
    bytes32 public constant upgradeRoot1To1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
}
