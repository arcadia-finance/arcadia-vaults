/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import "./fixtures/DeployedContracts.f.sol";
import { UniswapV3PricingModule } from "../PricingModules/UniswapV3/UniswapV3PricingModule.sol";
import { INonfungiblePositionManager } from "../PricingModules/UniswapV3/interfaces/INonfungiblePositionManager.sol";

abstract contract UniV3Test is DeployedContracts, Test {
    string RPC_URL = vm.envString("RPC_URL");
    uint256 fork;

    UniswapV3PricingModule uniV3PricingModule;
    INonfungiblePositionManager public uniV3 = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    event RiskManagerUpdated(address riskManager);

    //this is a before
    constructor() {
        fork = vm.createFork(RPC_URL);
    }

    //this is a before each
    function setUp() public virtual { }
}

/* ///////////////////////////////////////////////////////////////
                        DEPLOYMENT
/////////////////////////////////////////////////////////////// */
contract DeploymentTest is UniV3Test {
    function setUp() public override { }

    function testSuccess_deployment(
        address mainRegistry_,
        address oracleHub_,
        address riskManager_,
        address erc20PricingModule_
    ) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        uniV3PricingModule = new UniswapV3PricingModule(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_);
        vm.stopPrank();
    }
}

/*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT
///////////////////////////////////////////////////////////////*/
contract AssetManagementTest is UniV3Test {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        vm.selectFork(fork);

        vm.startPrank(deployer);
        uniV3PricingModule =
        new UniswapV3PricingModule(address(mainRegistry), address(oracleHub), deployer, address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();
    }

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != deployer);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3PricingModule.addAsset(address(uniV3));
        vm.stopPrank();
    }

    function testRevert_addAsset_NonUniswapV3PositionManager(address badAddress) public {
        vm.assume(badAddress != address(uniV3));

        vm.startPrank(deployer);
        vm.expectRevert();
        uniV3PricingModule.addAsset(badAddress);
        vm.stopPrank();
    }

    function testSuccess_addAsset() public {
        vm.prank(deployer);
        uniV3PricingModule.addAsset(address(uniV3));
    }
}
