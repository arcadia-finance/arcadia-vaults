/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import "../Integrations/IntegrationManager.sol";
import "../mockups/AdapterMock.sol";
import "../Vault.sol";

abstract contract IntegrationManagerTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    IntegrationManager im;
    AdapterMock adapter;

    address deployer = address(1);
    address vaultOwner = address(2);
    address mainRegistry = address(3);

    //Before
    constructor() {}

    //Before Each
    function setUp() public virtual {
        vm.startPrank(deployer);
        vault = new Vault();
        im = new IntegrationManager(address(mainRegistry));
        adapter = new AdapterMock(address(im));
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
contract PerformCallToAdapterTest is IntegrationManagerTest {
    function setUp() public override {
        super.setUp();
    }

    //Should fail because notVault is not IVault
    function testSuccess_receiveCallFromVaultNotVault(address notVault) public {
        vm.assume(notVault != address(vault));
        bytes memory callArgs_ =
            abi.encode(address(adapter), bytes4(keccak256("_selector(address,bytes,bytes)")), abi.encode("test"));

        vm.startPrank(notVault);
        vm.expectRevert(bytes("")); //This is a revert because caller does not implement IVault "owner" 
        im.receiveCallFromVault(msg.sender,callArgs_);
        vm.stopPrank();
    }

    // function testSuccess_receiveCallFromVaultNotVaultOwner(address notVaultOwner) public {
    //     vm.assume(notVaultOwner != address(vaultOwner));
    //     vm.assume(notVaultOwner != address(vault));
    //     bytes memory callArgs_ =
    //         abi.encode(address(adapter), bytes4(keccak256("takeOrder(address,bytes,bytes)")), abi.encode("test"));

    //     vm.startPrank(address(vault));
    //     vm.expectRevert("receiveCallFromVaultProxy: Unauthorized");
    //     im.receiveCallFromVault(notVaultOwner, callArgs_);
    //     vm.stopPrank();
    // }

    function testSuccess_callAdapter(address actionAddress, uint256 actionAmount) public {
        bytes4 _selector = bytes4(keccak256("_selector(address,bytes,bytes)"));
        address _vaultProxy = address(vault);
        bytes memory _integrationData = abi.encode(actionAddress, actionAmount);

        vm.startPrank(address(im));
        (bool success, bytes memory returnData) =
            address(adapter).call(abi.encodeWithSelector(_selector, _vaultProxy, _integrationData, bytes("")));
        vm.stopPrank();
    }

    function testSuccess_callAdapterNotIntegrationManager(
        address notIntegrationManager,
        address actionAddress,
        uint256 actionAmount
    ) public {
        vm.assume(notIntegrationManager != address(im));

        bytes4 _selector = bytes4(keccak256("_selector(address,bytes,bytes)"));
        address _vaultProxy = address(vault);
        bytes memory _integrationData = abi.encode(actionAddress, actionAmount);

        vm.startPrank(notIntegrationManager);

        vm.expectRevert("AC: Only the IntegrationManager can call this function");
        (bool success, bytes memory returnData) =
            address(adapter).call(abi.encodeWithSelector(_selector, _vaultProxy, _integrationData, bytes("")));
        vm.stopPrank();
    }

    function testSuccess_callAdapterIntegrationManager(address actionAddress, uint256 actionAmount) public {
        bytes4 _selector = bytes4(keccak256("_selector(address,bytes,bytes)"));
        address _vaultProxy = address(vault);
        bytes memory _integrationData = abi.encode(actionAddress, actionAmount);

        vm.startPrank(address(im));
        (bool success, bytes memory returnData) =
            address(adapter).call(abi.encodeWithSelector(_selector, _vaultProxy, _integrationData, bytes("")));
        vm.stopPrank();

        assertEq(success, true);
    }

    // Change some
}
