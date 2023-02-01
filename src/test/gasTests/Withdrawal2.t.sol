/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../fixtures/GastTestFixture.f.sol";

contract gasWithdrawal2_2ERC20 is GasTestFixture {
    using stdStorage for StdStorage;

    bytes3 public emptyBytes3;

    //this is a before
    constructor() GasTestFixture() { }

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
        vm.stopPrank();
    }

    function testGetValue_2_ERC20() public view {
        proxy.getVaultValue(0x0000000000000000000000000000000000000000);
    }

    function testGetRemainingValue_2_ERC20() public view {
        proxy.getFreeMargin();
    }

    function testBorrow() public {
        vm.prank(vaultOwner);
        pool.borrow(1, address(proxy), vaultOwner, emptyBytes3);
    }

    function testGenerateAssetData() public view {
        proxy.generateAssetData();
    }

    function testWithdrawal_1_ERC20_partly1() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 5 * 10 ** (Constants.ethDecimals - 1);

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(vaultOwner);
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testWithdrawal_2_ERC20_partly() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1 * 10 ** (Constants.ethDecimals - 1);
        assetAmounts[1] = 1 * 10 ** (Constants.linkDecimals - 1);

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 0;

        vm.startPrank(vaultOwner);
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testWithdrawal_2_ERC20_all() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 10 ** (Constants.ethDecimals);
        assetAmounts[1] = 10 ** (Constants.linkDecimals);

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 0;

        vm.startPrank(vaultOwner);
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
    }
}
