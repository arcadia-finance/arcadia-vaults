/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import { UniV3PriceModule } from "../PricingModules/UniswapV3/UniswapV3PricingModule.sol";
import { INonfungiblePositionManager } from "../PricingModules/UniswapV3/interfaces/INonfungiblePositionManager.sol";

abstract contract UniV3Test is DeployArcadiaVaults {
    string RPC_URL = vm.envString("RPC_URL");
    uint256 fork;

    UniV3PriceModule uniV3PriceModule;
    INonfungiblePositionManager public uniV3 = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    event RiskManagerUpdated(address riskManager);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.prank(creatorAddress);
        uniV3PriceModule =
        new UniV3PriceModule(address(mainRegistry), address(oracleHub), creatorAddress, address(standardERC20PricingModule));
    }

    //this is a before each
    function setUp() public virtual {
        fork = vm.createFork(RPC_URL);
    }
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
        vm.startPrank(creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        uniV3PriceModule = new UniV3PriceModule(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_);
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
    }

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3PriceModule.addAsset(address(uniV3));
        vm.stopPrank();
    }

    function testRevert_addAsset_NonUniswapV3PositionManager(address badAddress) public {
        vm.assume(badAddress != address(uniV3));

        vm.startPrank(creatorAddress);
        vm.expectRevert();
        uniV3PriceModule.addAsset(badAddress);
        vm.stopPrank();
    }

    function testSuccess_addAsset() public {
        vm.prank(creatorAddress);
        uniV3PriceModule.addAsset(address(uniV3));
    }
}
