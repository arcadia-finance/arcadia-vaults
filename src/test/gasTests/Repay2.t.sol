/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasRepay_2ERC20 is GasTestFixture {
    using stdStorage for StdStorage;

    uint128 maxCredit;

    //this is a before
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();

        vm.startPrank(vaultOwner);
        s_assetAddresses = new address[](2);
        s_assetAddresses[0] = address(eth);
        s_assetAddresses[1] = address(link);

        s_assetIds = new uint256[](2);
        s_assetIds[0] = 0;
        s_assetIds[1] = 0;

        s_assetAmounts = new uint256[](2);
        s_assetAmounts[0] = 10 ** Constants.ethDecimals;
        s_assetAmounts[1] = 10 ** Constants.linkDecimals;

        s_assetTypes = new uint256[](2);
        s_assetTypes[0] = 0;
        s_assetTypes[1] = 0;

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts, s_assetTypes);

        uint256 valueEth = (((10 ** 18 * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * s_assetAmounts[0])
            / 10 ** Constants.ethDecimals;
        uint256 valueLink = (((10 ** 18 * rateLinkToUsd) / 10 ** Constants.oracleLinkToUsdDecimals) * s_assetAmounts[1])
            / 10 ** Constants.linkDecimals;
        maxCredit = uint128(((valueEth + valueLink) / 10 ** (18 - Constants.daiDecimals) * collateralFactor) / 100);
        pool.borrow(maxCredit, address(proxy), vaultOwner);
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
