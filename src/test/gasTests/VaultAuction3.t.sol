/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasVaultAuction_1ERC201ERC721 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    //this is a before
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();

        vm.startPrank(vaultOwner);
        s_assetAddresses = new address[](2);
        s_assetAddresses[0] = address(eth);
        s_assetAddresses[1] = address(bayc);

        s_assetIds = new uint256[](2);
        s_assetIds[0] = 0;
        s_assetIds[1] = 1;

        s_assetAmounts = new uint256[](2);
        s_assetAmounts[0] = 10 ** Constants.ethDecimals;
        s_assetAmounts[1] = 1;

        s_assetTypes = new uint256[](2);
        s_assetTypes[0] = 0;
        s_assetTypes[1] = 1;

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts, s_assetTypes);

        uint256 valueEth = (((10 ** 18 * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * s_assetAmounts[0])
            / 10 ** Constants.ethDecimals;
        uint256 valueBayc = (
            (10 ** 18 * rateWbaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleWbaycToEthDecimals + Constants.oracleEthToUsdDecimals)
        ) * s_assetAmounts[1];
        pool.borrow(
            uint128(((valueEth + valueBayc) / 10 ** (18 - Constants.daiDecimals) * collateralFactor) / 100),
            address(proxy),
            vaultOwner,
            emptyBytes3
        );
        vm.stopPrank();

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd) / 2);
        vm.prank(oracleOwner);
        oracleWbaycToEth.transmit(int256(rateWbaycToEth) / 2);

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
