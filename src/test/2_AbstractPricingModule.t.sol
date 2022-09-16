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

    function testAssetWhitelistedWhenAddedToPricingModule(address assetAddress) public {
        vm.prank(creatorAddress);
        abstractPricingModule.setAssetInformation(assetAddress);

        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(assetAddress));
    }

    function testNonOwnerAddsExistingAssetToWhitelist(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.prank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testOwnerAddsNonExistingAssetToWhitelist() public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testOwnerAddsExistingAssetToWhitelist() public {
        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testNonOwnerRemovesExistingAssetFromWhitelist(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.prank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));

        vm.assume(unprivilegedAddress != address(this));
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testOwnerRemovesNonExistingAssetFromWhitelist() public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("Asset not known in Pricing Module");
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testOwnerRemovesExistingAssetFromWhitelist() public {
        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testNonOwnerAddsRemovedAssetToWhitelist(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);

        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));
        vm.stopPrank();

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(!abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }

    function testOwnerAddsRemovedAssetToWhitelist() public {
        vm.startPrank(creatorAddress);
        abstractPricingModule.setAssetInformation(address(eth));
        abstractPricingModule.removeFromWhiteList(address(eth));

        abstractPricingModule.addToWhiteList(address(eth));
        vm.stopPrank();

        assertTrue(abstractPricingModule.isAssetAddressWhiteListed(address(eth)));
    }
}
