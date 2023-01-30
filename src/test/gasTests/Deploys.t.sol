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
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();
    }

    function testDeployFactory() public {
        new FactoryExtension();
    }

    function testDeployVaultLogic() public {
        new Vault();
    }

    function testDeployMainRegistry() public {
        new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            }), address(factory)
        );
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
