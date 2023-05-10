/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Factory } from "../../Factory.sol";
import { Liquidator } from "../../Liquidator.sol";
import { Vault } from "../../Vault.sol";
import { MainRegistry } from "../../MainRegistry.sol";
import { OracleHub } from "../../OracleHub.sol";
import { StandardERC20PricingModule } from "../../PricingModules/StandardERC20PricingModule.sol";
import { LendingPool } from "../../../lib/arcadia-lending/src/LendingPool.sol";

contract DeployedContracts {
    Factory public constant factory = Factory(0x00CB53780Ea58503D3059FC02dDd596D0Be926cB);
    Liquidator public constant liqduidator = Liquidator(0xD2A34731586bD10B645f870f4C9DcAF4F9e3823C);
    Vault public constant vault = Vault(0x3Ae354d7E49039CcD582f1F3c9e65034fFd17baD);
    MainRegistry public constant mainRegistry = MainRegistry(0x046fc9f35EB7Cb165a5e07915d37bF4022b8dE33);
    OracleHub public constant oracleHub = OracleHub(0x950A8833b9533A19Fb4D1B2EFC823Ea6835f6d95);
    StandardERC20PricingModule public constant standardERC20PricingModule =
        StandardERC20PricingModule(0xC000d75D4221Ba9D7A788C81DCc0A4714B4aE9e5);
    LendingPool public constant lendingPool = LendingPool(0x9aa024D3fd962701ED17F76c17CaB22d3dc9D92d);

    address public constant deployer = 0xbA32A3D407353FC3adAA6f7eC6264Df5bCA51c4b;
}
