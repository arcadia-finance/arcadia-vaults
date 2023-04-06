/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {
    DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsMainnet
} from "./Constants/DeployConstants.sol";

import { PricingModule, StandardERC20PricingModule } from "../src/PricingModules/StandardERC20PricingModule.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { RiskConstants } from "../src/utils/RiskConstants.sol";

import { ERC20 } from "../lib/arcadia-lending/src/DebtToken.sol";

contract AddSingleAssetMainnet is Test {
    ERC20 public reth;

    OracleHub public oracleHub;
    StandardERC20PricingModule public standardERC20PricingModule;

    address[] public oracleRethToEthToUsdArr = new address[](2);

    PricingModule.RiskVarInput[] public riskVarsReth;

    OracleHub.OracleInformation public rethToEthOracleInfo;

    constructor() {
        /*///////////////////////////////////////////////////////////////
                          ADDRESSES
        ///////////////////////////////////////////////////////////////*/

        reth = ERC20(DeployAddresses.reth_mainnet);

        /*///////////////////////////////////////////////////////////////
                          ORACLE TRAINS
        ///////////////////////////////////////////////////////////////*/

        oracleRethToEthToUsdArr[0] = DeployAddresses.oracleRethToEth_mainnet;
        oracleRethToEthToUsdArr[1] = DeployAddresses.oracleEthToUsd_mainnet;

        /*///////////////////////////////////////////////////////////////
                          ORACLE INFO
        ///////////////////////////////////////////////////////////////*/

        rethToEthOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleRethToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "rETH",
            quoteAsset: "wETH",
            oracle: DeployAddresses.oracleRethToEth_mainnet,
            baseAssetAddress: DeployAddresses.reth_mainnet,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        /*///////////////////////////////////////////////////////////////
                            RISK VARS
        ///////////////////////////////////////////////////////////////*/

        riskVarsReth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.reth_collFact_1,
                liquidationFactor: DeployRiskConstantsMainnet.reth_liqFact_1
            })
        );
        riskVarsReth.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: DeployRiskConstantsMainnet.reth_collFact_2,
                liquidationFactor: DeployRiskConstantsMainnet.reth_liqFact_2
            })
        );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_MAINNET");

        vm.startBroadcast(deployerPrivateKey);

        oracleHub = OracleHub(0x950A8833b9533A19Fb4D1B2EFC823Ea6835f6d95);
        standardERC20PricingModule = StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);

        oracleHub.addOracle(rethToEthOracleInfo);

        PricingModule.RiskVarInput[] memory riskVarsReth_ = riskVarsReth;

        standardERC20PricingModule.addAsset(
            DeployAddresses.reth_mainnet,
            oracleRethToEthToUsdArr,
            riskVarsReth_,
            uint128(35_000 * 10 ** DeployNumbers.rethDecimals)
        );

        vm.stopBroadcast();
    }
}
