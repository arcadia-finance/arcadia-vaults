/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";

import "../AssetManagement/actions/UniswapV2SwapAction.sol";

import "../mockups/UniswapV2FactoryMock.sol";
import "../mockups/UniswapV2PairMock.sol";
import "../mockups/UniswapV2Router02Mock.sol";

import "../Vault.sol";

abstract contract UniswapV2SwapTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    UniswapV2Router02Mock routerMock;
    UniswapV2Router02Mock pairMock;
    UniswapV2Router02Mock factoryMock;
    UniswapV2SwapAction action;
    MainRegistry mainreg;


    address deployer = address(1);
    address vaultOwner = address(2);
    address mainRegistry = address(3);

    //Before
    constructor() {



        vm.startPrank(deployer);
        vault = new Vault();
        mainRegistry
        adapter = new UniswapV2SwapAction(address(im));
        vm.stopPrank();

        // Cheat owner
        uint256 slot = stdstore.target(address(vault)).sig(vault.owner.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 owner = bytes32(abi.encode(address(2)));
        vm.store(address(vault), loc, owner);

        //TODO Cheat IM in vault contract cause I don't want to break all old tests by changing vault initiate function just yet
        uint256 slot2 = stdstore.target(address(vault)).sig(vault.integrationManager.selector).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 integrationMan = bytes32(abi.encode(address(im)));
        vm.store(address(vault), loc2, integrationMan);

    }

    //Before Each
    function setUp() public virtual {}
}

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
//////////////////////////////////////////////////////////////*/

contract DeploymentTest is UniswapV2SwapTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {}
}

/*//////////////////////////////////////////////////////////////
                        ACTION SPECIFIC LOGIC
//////////////////////////////////////////////////////////////*/

contract executeActionTests is UniswapV2SwapTest {
    function setUp() public override {
        super.setUp();
    }
}
