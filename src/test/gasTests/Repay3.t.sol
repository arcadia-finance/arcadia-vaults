/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../fixtures/GastTestFixture.f.sol";

contract gasRepay_1ERC201ERC721 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    uint128 maxCredit;

    //this is a before
    constructor() GasTestFixture() { }

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

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts);

        uint256 valueEth = (((10 ** 18 * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * s_assetAmounts[0])
            / 10 ** Constants.ethDecimals;
        uint256 valueBayc = (
            (10 ** 18 * rateBaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleBaycToEthDecimals + Constants.oracleEthToUsdDecimals)
        ) * s_assetAmounts[1];
        maxCredit = uint128(((valueEth + valueBayc) / 10 ** (18 - Constants.daiDecimals) * collateralFactor) / 100);
        pool.borrow(maxCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();
    }

    function testRepay_partly() public {
        vm.prank(vaultOwner);
        pool.repay(maxCredit / 2, address(proxy));
    }

    function testRepay_exact() public {
        vm.prank(vaultOwner);
        pool.repay(maxCredit, address(proxy));
    }

    function testRepay_surplus() public {
        vm.prank(vaultOwner);
        pool.repay(maxCredit * 2, address(proxy));
    }
}
