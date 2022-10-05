/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";

abstract contract IntegrationManagerTest is Test {
    using stdStorage for StdStorage;

    //Before
    constructor() {}

    //Before Each
    function setUp() public virtual {
        
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

    }
}

/*//////////////////////////////////////////////////////////////
                        ACTION SPECIFIC LOGIC
//////////////////////////////////////////////////////////////*/

contract PerformCallToAdapterTest is IntegrationManagerTest {
    function setUp() public override {
        super.setUp();
    }

}
