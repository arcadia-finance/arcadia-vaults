/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasRepay_2ERC202ERC721 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    uint128 maxCredit;

    //this is a before
    constructor() GasTestFixture() { }

    //this is a before each
    function setUp() public override {
        super.setUp();

        vm.startPrank(vaultOwner);
        s_assetAddresses = new address[](4);
        s_assetAddresses[0] = address(eth);
        s_assetAddresses[1] = address(link);
        s_assetAddresses[2] = address(bayc);
        s_assetAddresses[3] = address(mayc);

        s_assetIds = new uint256[](4);
        s_assetIds[0] = 0;
        s_assetIds[1] = 0;
        s_assetIds[2] = 1;
        s_assetIds[3] = 1;

        s_assetAmounts = new uint256[](4);
        s_assetAmounts[0] = 10 ** Constants.ethDecimals;
        s_assetAmounts[1] = 10 ** Constants.linkDecimals;
        s_assetAmounts[2] = 1;
        s_assetAmounts[3] = 1;

        s_assetTypes = new uint256[](4);
        s_assetTypes[0] = 0;
        s_assetTypes[1] = 0;
        s_assetTypes[2] = 1;
        s_assetTypes[3] = 1;

        proxy.deposit(s_assetAddresses, s_assetIds, s_assetAmounts, s_assetTypes);

        uint256 valueEth = (((10 ** 18 * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * s_assetAmounts[0])
            / 10 ** Constants.ethDecimals;
        uint256 valueLink = (((10 ** 18 * rateLinkToUsd) / 10 ** Constants.oracleLinkToUsdDecimals) * s_assetAmounts[1])
            / 10 ** Constants.linkDecimals;
        uint256 valueBayc = (
            (10 ** 18 * rateWbaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleWbaycToEthDecimals + Constants.oracleEthToUsdDecimals)
        ) * s_assetAmounts[2];
        uint256 valueMayc = ((10 ** 18 * rateWmaycToUsd) / 10 ** Constants.oracleWmaycToUsdDecimals) * s_assetAmounts[3];
        maxCredit = uint128(
            ((valueEth + valueLink + valueBayc + valueMayc) / 10 ** (18 - Constants.daiDecimals) * collateralFactor)
                / 100
        );
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
