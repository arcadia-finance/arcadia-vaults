/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

library ArcadiaContractAddresses {
    // Todo: Update these addresses
    address public constant mainRegistry = address(0);
    address public constant factory = address(0);
    address public constant liquidator = address(0);
    address public constant oracleHub = address(0);
    address public constant riskModule = address(0);
    address public constant standardERC20PricingModule = address(0);
}

library ArcadiaAddresses {
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);
    address public constant multiSig3 = address(0);

    address public constant mainRegistryOwner = multiSig1;
    address public constant factoryOwner = multiSig1;
    address public constant liquidatorOwner = multiSig1;
    address public constant oracleHubOwner = multiSig1;
    address public constant standardERC20PricingModuleOwner = multiSig1;
    address public constant riskModuleOwner = multiSig1;
}
