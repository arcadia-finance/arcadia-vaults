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

    address public constant eth_optimism = 0x4200000000000000000000000000000000000006;
    address public constant usdc_optimism = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    address public constant dai_mainnet = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant eth_mainnet = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant link_mainnet = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public constant snx_mainnet = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;
    address public constant usdc_mainnet = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant btc_mainnet = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public constant oracleDaiToUsd = 0x0d79df66BE487753B02D015Fb622DED7f0E9798d;
    address public constant oracleEthToUsd = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address public constant oracleLinkToEth = 0xb4c4a493AB6356497713A78FFA6c60FB53517c63;
    address public constant oracleSnxToUsd = 0xdC5f59e61e51b90264b38F0202156F07956E2577;
    address public constant oracleUsdcToUsd = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7;
    address public constant oracleBtcToEth = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address public constant oracleDaiToUsd_mainnet = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address public constant oracleEthToUsd_mainnet = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant oracleLinkToEth_mainnet = 0xDC530D9457755926550b59e8ECcdaE7624181557;
    address public constant oracleSnxToUsd_mainnet = 0xDC3EA94CD0AC27d9A86C180091e7f78C683d3699;
    address public constant oracleUsdcToUsd_mainnet = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant oracleBtcToEth_mainnet = 0xdeb288F737066589598e9214E782fa5A8eD689e8;

    address public constant treasury_optimism = 0xBEB56fbEf3387af554A554E7DB25830eB7b92e32; // gnosis safe
    address public constant treasury_mainnet = 0xBEB56fbEf3387af554A554E7DB25830eB7b92e32; // gnosis safe
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
    bytes32 public constant upgradeRoot1To1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
}

library DeployRiskConstants {
    uint16 public constant dai_collFact_0 = 95; //usd
    uint16 public constant dai_collFact_1 = 70; //eth
    uint16 public constant dai_collFact_2 = 95; //usdc

    uint16 public constant eth_collFact_0 = 70; //usd
    uint16 public constant eth_collFact_1 = 95; //eth
    uint16 public constant eth_collFact_2 = 70; //usdc

    uint16 public constant link_collFact_0 = 65; //usd
    uint16 public constant link_collFact_1 = 70; //eth
    uint16 public constant link_collFact_2 = 65; //usdc

    uint16 public constant snx_collFact_0 = 65; //usd
    uint16 public constant snx_collFact_1 = 70; //eth
    uint16 public constant snx_collFact_2 = 65; //usdc

    uint16 public constant usdc_collFact_0 = 95; //usd
    uint16 public constant usdc_collFact_1 = 70; //eth
    uint16 public constant usdc_collFact_2 = 95; //usdc

    uint16 public constant btc_collFact_0 = 70; //usd
    uint16 public constant btc_collFact_1 = 75; //eth
    uint16 public constant btc_collFact_2 = 70; //usdc

    uint16 public constant dai_liqFact_0 = 98; //usd
    uint16 public constant dai_liqFact_1 = 80; //eth
    uint16 public constant dai_liqFact_2 = 98; //usdc

    uint16 public constant eth_liqFact_0 = 80; //usd
    uint16 public constant eth_liqFact_1 = 98; //eth
    uint16 public constant eth_liqFact_2 = 80; //usdc

    uint16 public constant link_liqFact_0 = 80; //usd
    uint16 public constant link_liqFact_1 = 82; //eth
    uint16 public constant link_liqFact_2 = 80; //usdc

    uint16 public constant snx_liqFact_0 = 80; //usd
    uint16 public constant snx_liqFact_1 = 82; //eth
    uint16 public constant snx_liqFact_2 = 80; //usdc

    uint16 public constant usdc_liqFact_0 = 98; //usd
    uint16 public constant usdc_liqFact_1 = 80; //eth
    uint16 public constant usdc_liqFact_2 = 98; //usdc

    uint16 public constant btc_liqFact_0 = 80; //usd
    uint16 public constant btc_liqFact_1 = 82; //eth
    uint16 public constant btc_liqFact_2 = 80; //usdc
}
