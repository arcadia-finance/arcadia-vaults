/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";

import "../Integrations/IntegrationManager.sol";
import "../Vault.sol";

abstract contract IntegrationManagerTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    IntegrationManager im;

    address deployer = address(1);
    address vaultOwner = address(2);

    //Before
    constructor() {
        
    }

    //Before Each
    function setUp() public virtual {
        vm.startPrank(deployer);
        vault = new Vault();
        im = new IntegrationManager();
        adapter = new MockAdapter();
        vm.stopPrank();

        // Cheat owner
        uint256 slot = stdstore.target(address(vault)).sig(vault.owner.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 owner = bytes32(abi.encode(address(2)));
        vm.store(address(vault), loc, owner);
        
        // Cheat IM in vault contract cause I don't want to break all old tests by changing vault initiate function just yet
        uint256 slot2 = stdstore.target(address(vault)).sig(vault.integrationManager.selector).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 integrationMan = bytes32(abi.encode(address(im)));
        vm.store(address(vault), loc2, integrationMan);

        // Cheat some assets to test some integrations.


    }
}

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
//////////////////////////////////////////////////////////////*/
contract DeploymentTest is IntegrationManagerTest {
    using stdStorage for StdStorage;
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        assertEq(vault.owner(), vaultOwner);
        assertEq(vault.integrationManager(), address(im));
    }
}

/*//////////////////////////////////////////////////////////////
                        COI LOGIC
//////////////////////////////////////////////////////////////*/
contract CallOnIntegrationTest is IntegrationManagerTest {
    
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_callOnIntegration() public {

        callArgs_ = abi.encode("adapter",bytes4(keccak256("takeOrder(address,bytes,bytes)")), gg );

        im.__callOnIntegration(vaultOwner, address(vault), _callArgs);
    }
}