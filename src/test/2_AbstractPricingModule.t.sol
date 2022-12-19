/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract AbstractPricingModuleExtension is PricingModule {
    constructor(address mainRegistry_, address oracleHub_) PricingModule(mainRegistry_, oracleHub_, msg.sender) {}

    function addAsset(address asset) public onlyOwner {
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        isAssetAddressWhiteListed[asset] = true;
    }
}

contract AbstractPricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    AbstractPricingModuleExtension internal abstractPricingModule;

    //this is a before
    constructor() DeployArcadiaVaults() {}

    //this is a before each
    function setUp() public {
        vm.prank(creatorAddress);
        abstractPricingModule = new AbstractPricingModuleExtension(
            address(mainRegistry),
            address(oracleHub)
        );
    }

    function testSuccess_addAsset_AssetWhitelistedWhenAddedToPricingModule(address asset) public {
        // Given: All necessary contracts deployed on setup
        vm.prank(creatorAddress);
        // When: creatorAddress calls addAsset
        abstractPricingModule.addAsset(asset);

        // Then: isAssetAddressWhiteListed should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(asset));
    }

    function testRevert_addToWhiteList_NonOwnerAddsExistingAssetToWhitelist(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress, creatorAddress calls addAsset with address(eth)
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.prank(creatorAddress);
        abstractPricingModule.addAsset(address(eth));

        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addToWhiteList

        // Then: addToWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_addToWhiteList_OwnerAddsNonExistingAssetToWhitelist() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addToWhiteList

        // Then: addToWhiteList should revert with "Asset not known in Pricing Module"
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_addToWhiteList_OwnerAddsExistingAssetToWhitelist() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset with address(eth)
        abstractPricingModule.addAsset(address(eth));
        // When: creatorAddress calls addToWhiteList with address(eth)
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_removeFromWhiteList_NonOwnerRemovesExistingAssetFromWhitelist(address unprivilegedAddress_)
        public
    {
        // Given: unprivilegedAddress_ is not creatorAddress and address(this), creatorAddress calls addAsset with address(eth)
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.assume(unprivilegedAddress_ != address(this));

        vm.prank(creatorAddress);
        abstractPricingModule.addAsset(address(eth));

        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls removeFromWhiteList

        // Then: removeFromWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_removeFromWhiteList_OwnerRemovesNonExistingAssetFromWhitelist() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(creatorAddress);
        // When: creatorAddress calls removeFromWhiteList

        // Then: removeFromWhiteList should revert with "Asset not known in Pricing Module"
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_removeFromWhiteList_OwnerRemovesExistingAssetFromWhitelist() public {
        vm.startPrank(creatorAddress);
        // Given: creatorAddress calls addAsset
        abstractPricingModule.addAsset(address(eth));
        // When: creatorAddress calls removeFromWhiteList
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return false
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testRevert_addToWhiteList_NonOwnerAddsRemovedAssetToWhitelist(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress, creatorAddress addAsset and removeFromWhiteList with address(eth)
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(creatorAddress);
        abstractPricingModule.addAsset(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addToWhiteList

        // Then: addToWhiteList should revert with "Ownable: caller is not the owner"
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // And: isAssetAddressWhiteListed for address(eth) should return false
        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testSuccess_addToWhiteList_OwnerAddsRemovedAssetToWhitelist() public {
        // Given: creatorAddress calls addAsset and removeFromWhiteList
        vm.startPrank(creatorAddress);
        abstractPricingModule.addAsset(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));

        // When: creatorAddress calls addToWhiteList
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        // Then: isAssetAddressWhiteListed for address(eth) should return true
        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    //function testSuccess_batchSetRiskVariables todo
    // testRevert_batchSetRiskVariables_NonOwner
    // testRevert_batchSetRiskVariables_NonEqualInputLists
    // testRevert_batchSetRiskVariables_InvalidValue
    // testSuccess_batchSetRiskVariables
}
