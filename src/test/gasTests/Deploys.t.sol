/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasDeploys is GasTestFixture {
    using stdStorage for StdStorage;

    //this is a before
    constructor() GasTestFixture() { }

    //this is a before each
    function setUp() public override {
        super.setUp();
    }

    function testDeployFactory() public {
        new FactoryExtension();
    }

    function testDeployVaultLogic() public {
        new Vault(address(mainRegistry), 1);
    }

    function testDeployMainRegistry() public {
        new mainRegistryExtension(address(factory));
    }

    function testDeployPricingModuleERC20() public {
        new StandardERC20PricingModule(address(mainRegistry), address(oracleHub));
    }

    function testDeployPricingModuleERC721() public {
        new FloorERC721PricingModule(address(mainRegistry), address(oracleHub));
    }

    function testDeployPricingModuleERC1155() public {
        new FloorERC1155PricingModule(address(mainRegistry), address(oracleHub));
    }

    function testDeployOracleHub() public {
        new OracleHub();
    }
}
