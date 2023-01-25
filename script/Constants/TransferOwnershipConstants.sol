/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

library ArcadiaContractAddresses {
    address public constant mainRegistry = "";
    address public constant factory = "";
    address public constant liquidator = "";
    address public constant oracleHub = "";
    address public constant riskModule = "";
    address public constant standardERC20PricingModule = "";
}

library ArcadiaAddresses {
    address public constant multiSig1 = "";
    address public constant multiSig2 = "";
    address public constant multiSig3 = "";

    address public mainRegistryOwner = multiSig1;
    address public factoryOwner = multiSig1;
    address public liquidatorOwner = multiSig1;
    address public oracleHubOwner = multiSig1;
    address public riskModuleOwner = multiSig1;
}
