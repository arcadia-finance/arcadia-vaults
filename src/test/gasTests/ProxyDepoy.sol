/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasProxyDeploy is GasTestFixture {
    using stdStorage for StdStorage;

    //this is a before
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();
    }

    function testCreateProxyVault() public {
        uint256 salt = 123456789;
        factory.createVault(salt, 0);
    }

    //This test should probably be deleted
    function testTransferOwnership() public {
        vm.prank(vaultOwner);
        factory.safeTransferFrom(vaultOwner, unprivilegedAddress, 1);
    }
}
