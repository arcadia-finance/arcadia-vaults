/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/GastTestFixture.f.sol";

contract gasDeposits is GasTestFixture {
    using stdStorage for StdStorage;

    //this is a before
    constructor() GasTestFixture() {}

    //this is a before each
    function setUp() public override {
        super.setUp();
    }

    function testDeposit_1_ERC20() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1e18;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_ERC20s() public {
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
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_3_ERC20s() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(snx);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;
        assetAmounts[2] = 10 ** Constants.snxDecimals;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_1_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        assetIds = new uint256[](1);
        assetIds[0] = 1;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_same_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(bayc);
        assetAddresses[1] = address(bayc);

        assetIds = new uint256[](2);
        assetIds[0] = 2;
        assetIds[1] = 3;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 1;
        assetTypes[1] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(bayc);
        assetAddresses[1] = address(mayc);

        assetIds = new uint256[](2);
        assetIds[0] = 4;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 1;
        assetTypes[1] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_1_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        assetIds = new uint256[](1);
        assetIds[0] = 1;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        assetTypes = new uint256[](1);
        assetTypes[0] = 2;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(interleave);
        assetAddresses[1] = address(genericStoreFront);

        assetIds = new uint256[](2);
        assetIds[0] = 1;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 2;
        assetTypes[1] = 2;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_1_ERC20_1_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](2);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);

        assetIds = new uint256[](2);
        assetIds[0] = 1;
        assetIds[1] = 5;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;

        assetTypes = new uint256[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_1_ERC20_2_same_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(bayc);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 6;
        assetIds[2] = 7;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_1_ERC20_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](3);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);

        assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 8;
        assetIds[2] = 2;

        assetAmounts = new uint256[](3);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;

        assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_ERC20_2_diff_ERC721() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](4);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);
        assetAddresses[3] = address(snx);

        assetIds = new uint256[](4);
        assetIds[0] = 0;
        assetIds[1] = 9;
        assetIds[2] = 3;
        assetIds[3] = 0;

        assetAmounts = new uint256[](4);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 100;

        assetTypes = new uint256[](4);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_ERC20_2_same_ERC721_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](6);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(bayc);
        assetAddresses[3] = address(interleave);
        assetAddresses[4] = address(genericStoreFront);
        assetAddresses[5] = address(snx);

        assetIds = new uint256[](6);
        assetIds[0] = 0;
        assetIds[1] = 10;
        assetIds[2] = 11;
        assetIds[3] = 1;
        assetIds[4] = 1;
        assetIds[5] = 1;

        assetAmounts = new uint256[](6);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 10;
        assetAmounts[4] = 10;
        assetAmounts[5] = 100;

        assetTypes = new uint256[](6);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 2;
        assetTypes[4] = 2;
        assetTypes[5] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testDeposit_2_ERC20_2_diff_ERC721_2_diff_ERC1155() public {
        address[] memory assetAddresses;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        assetAddresses = new address[](6);
        assetAddresses[0] = address(link);
        assetAddresses[1] = address(bayc);
        assetAddresses[2] = address(mayc);
        assetAddresses[3] = address(interleave);
        assetAddresses[4] = address(genericStoreFront);
        assetAddresses[5] = address(snx);

        assetIds = new uint256[](6);
        assetIds[0] = 0;
        assetIds[1] = 12;
        assetIds[2] = 4;
        assetIds[3] = 1;
        assetIds[4] = 1;
        assetIds[5] = 1;

        assetAmounts = new uint256[](6);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1;
        assetAmounts[2] = 1;
        assetAmounts[3] = 10;
        assetAmounts[4] = 10;
        assetAmounts[5] = 100;

        assetTypes = new uint256[](6);
        assetTypes[0] = 0;
        assetTypes[1] = 1;
        assetTypes[2] = 1;
        assetTypes[3] = 2;
        assetTypes[4] = 2;
        assetTypes[5] = 0;

        vm.prank(vaultOwner);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }
}
