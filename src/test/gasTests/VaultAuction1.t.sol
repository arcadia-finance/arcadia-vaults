/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../fixtures/GastTestFixture.f.sol";

contract gasVaultAuction_1ERC20 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    //this is a before
    constructor() GasTestFixture() { }

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

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts);

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
        pool.liquidateVault(address(proxy));
    }

    function testAuctionPriceStart() public {
        vm.roll(1); //compile warning to make it a view
        liquidator.getPriceOfVault(address(proxy));
    }

    function testAuctionPriceBl100() public {
        vm.roll(100);
        liquidator.getPriceOfVault(address(proxy));
    }

    function testAuctionPriceBl500() public {
        vm.roll(500);
        liquidator.getPriceOfVault(address(proxy));
    }

    function testAuctionPriceBl1000() public {
        vm.roll(1000);
        liquidator.getPriceOfVault(address(proxy));
    }

    function testAuctionPriceBl1500() public {
        vm.roll(1500);
        liquidator.getPriceOfVault(address(proxy));
    }

    function testAuctionPriceBl2000() public {
        vm.roll(2000);
        liquidator.getPriceOfVault(address(proxy));
    }
}
