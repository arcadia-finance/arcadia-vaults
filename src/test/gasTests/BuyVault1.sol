/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasBuyVault_1ERC20 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    //this is a before
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();

        vm.startPrank(vaultOwner);
        s_assetAddresses = new address[](1);
        s_assetAddresses[0] = address(eth);

        s_assetIds = new uint256[](1);
        s_assetIds[0] = 0;

        s_assetAmounts = new uint256[](1);
        s_assetAmounts[0] = 10 ** Constants.ethDecimals;

        s_assetTypes = new uint256[](1);
        s_assetTypes[0] = 0;

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts, s_assetTypes);

        uint256 valueEth = (((10 ** 18 * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * s_assetAmounts[0])
            / 10 ** Constants.ethDecimals;
        pool.borrow(
            uint128((valueEth / 10 ** (18 - Constants.daiDecimals) * collateralFactor) / 100),
            address(proxy),
            vaultOwner,
            emptyBytes3
        );
        vm.stopPrank();

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd) / 2);

        vm.prank(liquidatorBot);
        factory.liquidate(address(proxy));

        vm.prank(liquidityProvider);
        dai.transfer(vaultBuyer, 10 ** 10 * 10 ** 18);
    }

    function testBuyVaultStart() public {
        vm.roll(1); //compile warning to make it a view
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }

    function testBuyVaultBl100() public {
        vm.roll(100);
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }

    function testBuyVaultBl500() public {
        vm.roll(500);
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }

    function testBuyVaultBl1000() public {
        vm.roll(1000);
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }

    function testBuyVaultBl1500() public {
        vm.roll(1500);
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }

    function testBuyVaultBl2000() public {
        vm.roll(2000);
        vm.prank(vaultBuyer);
        liquidator.buyVault(address(proxy));
    }
}
