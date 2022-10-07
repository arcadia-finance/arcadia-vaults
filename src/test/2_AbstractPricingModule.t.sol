/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/AbstractPricingModule.sol";
import "../AssetRegistry/MainRegistry.sol";

contract AbstractPricingModuleForTest is PricingModule {
    constructor(address mainRegistry, address oracleHub) PricingModule(mainRegistry, oracleHub) {}

    function setAssetInformation(address assetAddress) public onlyOwner {
        if (!inPricingModule[assetAddress]) {
            inPricingModule[assetAddress] = true;
            assetsInPricingModule.push(assetAddress);
        }
        isAssetAddressWhiteListed[assetAddress] = true;
    }
}

contract AbstractPricingModuleTest is Test {
    using stdStorage for StdStorage;

    AbstractPricingModuleForTest internal abstractPricingModule;
    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    ERC20Mock private snx;
    ERC20Mock private link;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        snx = new ERC20Mock("SNX Mock", "mSNX", uint8(Constants.snxDecimals));
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals)
        );

        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        oracleHub = new OracleHub();
        vm.stopPrank();
    }

    //this is a before each
    function setUp() public {
        vm.prank(creatorAddress);
        abstractPricingModule = new AbstractPricingModuleForTest(
            address(mainRegistry),
            address(oracleHub)
        );
    }

    function testSuccess_setAssetInformation_AssetWhitelistedWhenAddedToPricingModule(address assetAddress) public {
        // Given: 
        vm.prank(creatorAddress);
        // When: creatorAddress setAssetInformation
        abstractPricingModule.setAssetInformation(assetAddress);

        // Then: isAssetAddressWhiteListed should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(assetAddress));
    }

    function testRevert_addToWhiteList_NonOwnerAddsExistingAssetToWhitelist(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress, creatorAddress setAssetInformation with address(eth)
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.prank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress addToWhiteList

        // Then: addToWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_addToWhiteList_OwnerAddsNonExistingAssetToWhitelist() public {
        // Given: 
        vm.startPrank(creatorAddress);
        // When: creatorAddress addToWhiteList

        // Then: addToWhiteList should revert with "Asset not known in Pricing Module"
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_addToWhiteList_OwnerAddsExistingAssetToWhitelist() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress setAssetInformation with address(eth) input
        abstractPricingModule.setAssetInformation(address(eth));
        // When: creatorAddress addToWhiteList with address(eth) input
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_removeFromWhiteList_NonOwnerRemovesExistingAssetFromWhitelist(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.prank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));

        vm.assume(unprivilegedAddress != address(this));
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress removeFromWhiteList

        // Then: removeFromWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_removeFromWhiteList_OwnerRemovesNonExistingAssetFromWhitelist() public {
        // Given:
        vm.startPrank(creatorAddress);
        // When: creatorAddress removeFromWhiteList

        // Then: removeFromWhiteList should revert with "Asset not known in Pricing Module"
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false 
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_removeFromWhiteList_OwnerRemovesExistingAssetFromWhitelist() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress setAssetInformation
        abstractPricingModule.setAssetInformation(address(eth));
        // When: creatorAddress removeFromWhiteList
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return false 
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_addToWhiteList_NonOwnerAddsRemovedAssetToWhitelist(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress, creatorAddress setAssetInformation and removeFromWhiteList
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress addToWhiteList

        // Then: addToWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false 
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_addToWhiteList_OwnerAddsRemovedAssetToWhitelist() public {
        // Given: creatorAddress setAssetInformation and removeFromWhiteList
        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));

        // When: creatorAddress addToWhiteList
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }
}
