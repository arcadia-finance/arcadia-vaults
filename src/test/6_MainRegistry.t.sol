/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";
import "../utils/StringHelpers.sol";
import "../utils/CompareArrays.sol";

abstract contract MainRegistryTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    //this is a before
    constructor() DeployArcadiaVaults() { }

    //this is a before each
    function setUp() public virtual {
        vm.startPrank(creatorAddress);
        mainRegistry = new mainRegistryExtension(address(factory));

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub),
            0
        );
        floorERC721PricingModule = new FloorERC721PricingModule(
            address(mainRegistry),
            address(oracleHub),
            1
        );
        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistry),
            address(oracleHub),
            2
        );
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
                        DEPLOYMENT
/////////////////////////////////////////////////////////////// */
contract DeploymentTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment_UsdAsBaseCurrency() public {
        // Given: All necessary contracts deployed on setup
        // When:
        // Then: baseCurrencyLabel should return "USD"
        (, address assetaddress,,, bytes8 baseCurrencyLabel) = mainRegistry.baseCurrencyToInformation(0);
        assertEq(assetaddress, address(0));
        assertTrue(bytes8("USD") == baseCurrencyLabel);
        assertEq(mainRegistry.assetToBaseCurrency(address(0)), 0);
        assertEq(mainRegistry.baseCurrencies(0), address(0));
    }

    function testSuccess_deployment_BaseCurrencyCounterIsOne() public {
        // Given: All necessary contracts deployed on setup
        // When:
        // Then: baseCurrencyCounter should return 1
        assertEq(1, mainRegistry.baseCurrencyCounter());
    }
}

/* ///////////////////////////////////////////////////////////////
                    EXTERNAL CONTRACTS
/////////////////////////////////////////////////////////////// */
contract ExternalContractsTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_setAllowedAction_Owner(address action, bool allowed) public {
        vm.prank(creatorAddress);
        mainRegistry.setAllowedAction(action, allowed);

        assertEq(mainRegistry.isActionAllowed(action), allowed);
    }

    function testRevert_setAllowedAction_NonOwner(address action, bool allowed, address nonAuthorized) public {
        vm.assume(nonAuthorized != creatorAddress);

        vm.startPrank(nonAuthorized);
        vm.expectRevert("UNAUTHORIZED");
        mainRegistry.setAllowedAction(action, allowed);
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
                    BASE CURRENCY MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract BaseCurrencyManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_addBaseCurrency_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addBaseCurrency

        // Then: addBaseCurrency should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        vm.stopPrank();
    }

    function testRevert_addBaseCurrency_duplicateBaseCurrency() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint128).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);

        // When: creatorAddress calls addBaseCurrency
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );

        // and: creatorAddress calls addBaseCurrency again with the same baseCurrency
        // then: addBaseCurrency should revert with "MR_ABC: BaseCurrency exists"
        vm.expectRevert("MR_ABC: BaseCurrency exists");
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        vm.stopPrank();
    }

    function testSuccess_addBaseCurrency() public {
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint128).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);

        // When: creatorAddress calls addBaseCurrency
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        vm.stopPrank();

        // Then: baseCurrencyCounter should return 2
        assertEq(2, mainRegistry.baseCurrencyCounter());
    }
}

/* ///////////////////////////////////////////////////////////////
                    PRICE MODULE MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract PriceModuleManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_addPricingModule_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addPricingModule

        // Then: addPricingModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testRevert_addPricingModule_AddExistingPricingModule() public {
        // Given: All necessary contracts deployed on setup

        vm.startPrank(creatorAddress);
        // When: creatorAddress calls addPricingModule for address(standardERC20PricingModule)

        // Then: addPricingModule should revert with "MR_APM: PriceMod. not unique"
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.expectRevert("MR_APM: PriceMod. not unique");
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();
    }

    function testSuccess_addPricingModule() public {
        // Given: All necessary contracts deployed on setup
        // When: creatorAddress calls addPricingModule for address(standardERC20PricingModule)
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        vm.stopPrank();

        // Then: isPricingModule for address(standardERC20PricingModule) should return true
        assertTrue(mainRegistry.isPricingModule(address(standardERC20PricingModule)));
    }
}

/* ///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract AssetManagementTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));

        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );
        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );
        riskVars.push(
            PricingModule.RiskVarInput({
                baseCurrency: 2,
                asset: address(0),
                collateralFactor: collateralFactor,
                liquidationFactor: liquidationFactor
            })
        );

        PricingModule.RiskVarInput[] memory riskVars_ = riskVars;

        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, riskVars_, type(uint128).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, riskVars_, type(uint128).max);

        vm.stopPrank();

        vm.startPrank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                    )
                )
            ),
            0,
            address(0)
        );
        proxy = Vault(proxyAddr);
        vm.stopPrank();
    }

    function testRevert_addAsset_NonPricingModule(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not address(standardERC20PricingModule), address(floorERC721PricingModule) or address(floorERC1155PricingModule)
        vm.assume(unprivilegedAddress_ != address(standardERC20PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC721PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC1155PricingModule));
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset
        // Then: addAsset should revert with "MR: Only PriceMod."
        vm.expectRevert("MR: Only PriceMod.");
        mainRegistry.addAsset(address(eth), 0);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteAsset() public {
        // Given: creatorAddress calls addPricingModule and setAssetsToNonUpdatable,
        vm.startPrank(creatorAddress);
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        vm.stopPrank();

        // When: standardERC20PricingModule has eth added as asset

        vm.startPrank(address(floorERC721PricingModule));
        // When: floorERC721PricingModule calls addAsset
        // Then: addAsset should revert with "MR_AA: Asset already in mainreg"
        vm.expectRevert("MR_AA: Asset already in mainreg");
        mainRegistry.addAsset(address(eth), 0);
        vm.stopPrank();
    }

    function testRevert_addAsset_InvalidAssetType(address newAsset, uint256 assetType) public {
        vm.assume(mainRegistry.inMainRegistry(newAsset) == false);
        vm.assume(assetType > type(uint96).max);

        // When: standardERC20PricingModule calls addAsset with assetType greater than uint96.max
        // Then: addAsset should revert with "MR_AA: Invalid AssetType"
        vm.startPrank(address(standardERC20PricingModule));
        vm.expectRevert("MR_AA: Invalid AssetType");
        mainRegistry.addAsset(newAsset, assetType);
        vm.stopPrank();
    }

    function testSuccess_addAsset(address newAsset, uint96 assetType) public {
        vm.assume(mainRegistry.inMainRegistry(newAsset) == false);
        // When: standardERC20PricingModule calls addAsset with input of address(eth)
        vm.startPrank(address(standardERC20PricingModule));
        mainRegistry.addAsset(newAsset, assetType);
        vm.stopPrank();

        // Then: inMainRegistry for address(eth) should return true
        assertTrue(mainRegistry.inMainRegistry(newAsset));
        (uint96 assetType_, address pricingModule) = mainRegistry.assetToAssetInformation(newAsset);
        assertEq(assetType_, assetType);
        assertEq(pricingModule, address(standardERC20PricingModule));
    }

    function testRevert_batchProcessDeposit_NonVault(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != proxyAddr);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("MR: Only Vaults.");
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessDeposit_lengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(dai);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1000;

        vm.startPrank(proxyAddr);
        vm.expectRevert("MR_BPD: LENGTH_MISMATCH");
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessDeposit_exposureNotSufficient(uint128 newMaxExposure, uint128 amount) public {
        vm.assume(newMaxExposure < amount);

        vm.prank(creatorAddress);
        standardERC20PricingModule.setExposureOfAsset(address(eth), newMaxExposure);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(proxyAddr);
        vm.expectRevert("APM_PD: Exposure not in limits");
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessDeposit_AssetNotInMainreg(address asset) public {
        vm.assume(!mainRegistry.inMainRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(proxyAddr);
        vm.expectRevert("MR_BPD: Asset not in mainreg");
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessDeposit_Paused(uint128 amountEth, uint128 amountLink, address guardian) public {
        // Given: Assets
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountEth;
        assetAmounts[1] = amountLink;

        // When: guardian pauses mainRegistry
        vm.prank(creatorAddress);
        mainRegistry.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        mainRegistry.pause();

        // Then: batchProcessDeposit should reverted
        vm.prank(proxyAddr);
        vm.expectRevert("Guardian: deposit paused");
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
    }

    function testSuccess_batchProcessDeposit_SingleAsset(uint128 amount) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(proxyAddr);
        uint256[] memory assetTypes = mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        (, uint128 exposure) = standardERC20PricingModule.exposure(address(eth));
        assertEq(exposure, amount);
    }

    function testSuccess_batchProcessDeposit_MultipleAssets(uint128 amountEth, uint128 amountLink) public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountEth;
        assetAmounts[1] = amountLink;

        vm.prank(proxyAddr);
        uint256[] memory assetTypes = mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 0);

        (, uint256 exposureEth) = standardERC20PricingModule.exposure(address(eth));
        (, uint256 exposureLink) = standardERC20PricingModule.exposure(address(link));

        assertEq(exposureEth, amountEth);
        assertEq(exposureLink, amountLink);
    }

    function testSuccess_batchProcessDeposit_directCall(uint128 amountLink) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        vm.startPrank(proxyAddr);
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        (, uint128 newExposure) = standardERC20PricingModule.exposure(address(link));

        assertEq(newExposure, amountLink);
    }

    function testRevert_batchProcessDeposit_delegateCall(uint128 amountLink) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        vm.startPrank(proxyAddr);
        vm.expectRevert("MR: No delegate.");
        (bool success,) = address(mainRegistry).delegatecall(
            abi.encodeWithSignature(
                "batchProcessDeposit(address[] calldata,uint256[] calldata,uint256[] calldata)",
                assetAddresses,
                assetIds,
                assetAmounts
            )
        );
        vm.stopPrank();

        success; //avoid warning
    }

    function testRevert_batchProcessWithdrawal_NonVault(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != proxyAddr);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("MR: Only Vaults.");
        mainRegistry.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessWithdrawal_lengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(dai);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        vm.startPrank(proxyAddr);
        vm.expectRevert("MR_BPW: LENGTH_MISMATCH");
        mainRegistry.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_batchProcessWithdrawal_Paused(uint128 amountLink, address guardian) public {
        // Given: Assets are deposited
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        vm.prank(proxyAddr);
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        // When: Main registry is paused
        vm.prank(creatorAddress);
        mainRegistry.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        mainRegistry.pause();

        // Then: Withdrawal is reverted due to paused main registry
        vm.startPrank(proxyAddr);
        vm.expectRevert("Guardian: withdraw paused");
        mainRegistry.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testSuccess_batchProcessWithdrawal(uint128 amountDeposited, uint128 amountWithdrawn) public {
        vm.assume(amountDeposited >= amountWithdrawn);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        vm.prank(proxyAddr);
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        (, uint256 exposure) = standardERC20PricingModule.exposure(address(eth));

        assertEq(exposure, amountDeposited);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(proxyAddr);
        uint256[] memory assetTypes = mainRegistry.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        (, exposure) = standardERC20PricingModule.exposure(address(eth));

        assertEq(exposure, amountDeposited - amountWithdrawn);
    }

    function testSuccess_batchProcessWithdrawal_directCall(uint128 amountLink) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        vm.startPrank(proxyAddr);
        mainRegistry.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.startPrank(proxyAddr);
        mainRegistry.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        (, uint128 endExposure) = standardERC20PricingModule.exposure(address(link));

        assertEq(endExposure, 0);
    }

    function testRevert_batchProcessWithdrawal_delegateCall(uint128 amountLink) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        vm.startPrank(proxyAddr);
        vm.expectRevert("MR: No delegate.");
        (bool success,) = address(mainRegistry).delegatecall(
            abi.encodeWithSignature(
                "batchProcessWithdrawal(address[] calldata,uint256[] calldata,uint256[] calldata)",
                assetAddresses,
                assetIds,
                assetAmounts
            )
        );
        vm.stopPrank();

        success; //avoid warning
    }
}

/* ///////////////////////////////////////////////////////////////
                        PRICING LOGIC
/////////////////////////////////////////////////////////////// */
contract PricingLogicTest is MainRegistryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(floorERC721PricingModule));
        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint128).max);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);

        floorERC721PricingModule.addAsset(
            address(bayc), 0, type(uint256).max, oracleWbaycToEthEthToUsd, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testSucccess_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsd(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        // Given: linkDecimals is less than equal to 18, rateEthToUsdNew is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency with emptyList, calls addPricingModule with standardERC20PricingModule,
        // oracleOwner calls transmit with rateEthToUsdNew and rateLinkToUsd
        vm.assume(linkDecimals <= 18);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink
                <= type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD
                    / 10 ** (Constants.oracleEthToUsdDecimals - Constants.oracleLinkToUsdDecimals)
        );
        vm.assume(
            amountLink
                <= (
                    ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals)
                        / 10 ** Constants.oracleLinkToUsdDecimals
                ) * 10 ** linkDecimals
        );

        vm.startPrank(creatorAddress);
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            linkDecimals
        );
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // actualTotalValue is getTotalValue for assetAddresses, assetIds, assetAmounts and Constants.EthBaseCurrency,
        // expectedTotalValue is linkValueInEth
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        uint256 actualTotalValue =
            mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 linkValueInUsd = (assetAmounts[0] * rateLinkToUsd * Constants.WAD)
            / 10 ** Constants.oracleLinkToUsdDecimals / 10 ** linkDecimals;
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsdNew
            / 10 ** (18 - Constants.ethDecimals);

        uint256 expectedTotalValue = linkValueInEth;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdOverflow(
        uint256 rateEthToUsdNew,
        uint256 amountLink,
        uint8 linkDecimals
    ) public {
        // Given: linkDecimals is less than oracleEthToUsdDecimals, rateEthToUsdNew is less than equal to max uint256 value and bigger than 0,
        // creatorAddress calls addBaseCurrency, calls addPricingModule with standardERC20PricingModule,
        // oracleOwner calls transmit with rateEthToUsdNew and rateLinkToUsd
        vm.assume(linkDecimals < Constants.oracleEthToUsdDecimals);
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew > 0);
        vm.assume(
            amountLink
                > ((type(uint256).max / uint256(rateLinkToUsd) / Constants.WAD) * 10 ** Constants.oracleEthToUsdDecimals)
                    / 10 ** (Constants.oracleLinkToUsdDecimals - linkDecimals)
        );

        vm.startPrank(creatorAddress);
        link = new ERC20Mock(
            "LINK Mock",
            "mLINK",
            linkDecimals);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // getTotalValue is called
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        // Then: getTotalValue should revert with arithmetic overflow
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);
    }

    function testRevert_getTotalValue_CalculateValueInBaseCurrencyFromValueInUsdWithRateZero(uint256 amountLink)
        public
    {
        // Given: amountLink bigger than 0, oracleOwner calls transmit for 0 and rateLinkToUsd
        vm.assume(amountLink > 0);

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(0));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(link), assetIds index 0 is 0, assetAmounts index 0 is amountLink,
        // getTotalValue is called
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountLink;

        // Then: getTotalValue should revert
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);
    }

    function testRevert_getTotalValue_UnknownBaseCurrency() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(eth), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GTV: Unknown BaseCurrency"
        vm.expectRevert("MR_GTV: Unknown BaseCurrency");
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownBaseCurrency() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(eth), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "" ("EvmError: Revert")
        vm.expectRevert();
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.SafemoonBaseCurrency);
    }

    function testRevert_getTotalValue_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(safemoon), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "MR_GTV: Unknown asset"
        vm.expectRevert(bytes(""));
        mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testRevert_getListOfValuesPerAsset_UnknownAsset() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: assetAddresses index 0 is address(safemoon), index 1 is address(bayc), assetIds index 0 and 1 is 0, assetAmounts index 0 and 1 is 10
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(safemoon);
        assetAddresses[1] = address(bayc);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;
        // When: getTotalValue called

        // Then: getTotalValue should revert with "" ("EvmError: Revert")
        vm.expectRevert();
        mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.UsdBaseCurrency);
    }

    function testSuccess_getTotalValue() public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency or USD
        // Given: oracleOwner calls transmit for rateEthToUsd, rateLinkToUsd and rateWbaycToEth
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(link), index 2 is address(bayc), assetIds index 0, 1 and 2 is 0,
        // assetAmounts index 0 is 10 multiplied by ethDecimals, index 1 is 10 multiplied by linkDecimals, index 2 is 1, actualTotalValue is getTotalValue,
        // expectedTotalValue is ethValueInEth plus linkValueInEth plus baycValueInEth
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        uint256 actualTotalValue =
            mainRegistry.getTotalValue(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 ethValueInEth = assetAmounts[0];
        uint256 linkValueInUsd = (Constants.WAD * rateLinkToUsd * assetAmounts[1])
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsd
            / 10 ** (18 - Constants.ethDecimals);
        uint256 baycValueInEth = (Constants.WAD * rateWbaycToEth * assetAmounts[2])
            / 10 ** Constants.oracleWbaycToEthDecimals / 10 ** (18 - Constants.ethDecimals);

        uint256 expectedTotalValue = ethValueInEth + linkValueInEth + baycValueInEth;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testSuccess_getListOfValuesPerAsset() public {
        // Given: oracleOwner calls transmit for rateEthToUsd, rateLinkToUsd and rateWbaycToEth
        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd));
        oracleLinkToUsd.transmit(int256(rateLinkToUsd));
        oracleWbaycToEth.transmit(int256(rateWbaycToEth));
        vm.stopPrank();

        // When: assetAddresses index 0 is address(eth), index 1 is address(link), index 2 is address(bayc), assetIds index 0, 1 and 2 is 0,
        // assetAmounts index 0 is 10 multiplied by ethDecimals, index 1 is 10 multiplied by linkDecimals, index 2 is 1, actualListOfValuesPerAsset is getListOfValuesPerAsset,
        // expectedListOfValuesPerAsset index 0 is ethValueInEth, index 1 is linkValueInEth, index 2 is baycValueInEth
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.ethDecimals;
        assetAmounts[1] = 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        RiskModule.AssetValueAndRiskVariables[] memory actualValuesPerAsset =
            mainRegistry.getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, Constants.EthBaseCurrency);

        uint256 ethValueInEth = assetAmounts[0];
        uint256 linkValueInUsd = (Constants.WAD * rateLinkToUsd * assetAmounts[1])
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 linkValueInEth = (linkValueInUsd * 10 ** Constants.oracleEthToUsdDecimals) / rateEthToUsd
            / 10 ** (18 - Constants.ethDecimals);
        uint256 baycValueInEth = (Constants.WAD * rateWbaycToEth * assetAmounts[2])
            / 10 ** Constants.oracleWbaycToEthDecimals / 10 ** (18 - Constants.ethDecimals);

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = ethValueInEth;
        expectedListOfValuesPerAsset[1] = linkValueInEth;
        expectedListOfValuesPerAsset[2] = baycValueInEth;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].valueInBaseCurrency;
        }
        // Then: expectedListOfValuesPerAsset array should be equal to actualListOfValuesPerAsset
        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }

    function testSuccess_getCollateralValue(int64 rateEthToUsd_, uint64 amountEth, uint16 collateralFactor_) public {
        vm.assume(collateralFactor_ <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(rateEthToUsd_ > 0);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(rateEthToUsd_);

        uint256 ethValueInUsd = Constants.WAD * uint64(rateEthToUsd_) / 10 ** Constants.oracleEthToUsdDecimals
            * amountEth / 10 ** Constants.ethDecimals / 10 ** (18 - Constants.usdDecimals);
        vm.assume(ethValueInUsd > 0);

        PricingModule.RiskVarInput[] memory riskVarsInput = new PricingModule.RiskVarInput[](1);
        riskVarsInput[0].asset = address(eth);
        riskVarsInput[0].baseCurrency = uint8(Constants.UsdBaseCurrency);
        riskVarsInput[0].collateralFactor = collateralFactor_;

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVarsInput);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountEth;

        uint256 actualCollateralValue =
            mainRegistry.getCollateralValue(assetAddresses, assetIds, assetAmounts, address(0));

        uint256 expectedCollateralValue = ethValueInUsd * collateralFactor_ / 100;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }

    function testSuccess_getLiquidationValue(int64 rateEthToUsd_, uint64 amountEth, uint16 liquidationFactor_) public {
        vm.assume(liquidationFactor_ <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        vm.assume(rateEthToUsd_ > 0);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(rateEthToUsd_);

        uint256 ethValueInUsd = Constants.WAD * uint64(rateEthToUsd_) / 10 ** Constants.oracleEthToUsdDecimals
            * amountEth / 10 ** Constants.ethDecimals / 10 ** (18 - Constants.usdDecimals);
        vm.assume(ethValueInUsd > 0);

        PricingModule.RiskVarInput[] memory riskVarsInput = new PricingModule.RiskVarInput[](1);
        riskVarsInput[0].asset = address(eth);
        riskVarsInput[0].baseCurrency = uint8(Constants.UsdBaseCurrency);
        riskVarsInput[0].liquidationFactor = liquidationFactor_;

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVarsInput);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountEth;

        uint256 actualLiquidationValue =
            mainRegistry.getLiquidationValue(assetAddresses, assetIds, assetAmounts, address(0));

        uint256 expectedLiquidationValue = ethValueInUsd * liquidationFactor_ / 100;

        assertEq(expectedLiquidationValue, actualLiquidationValue);
    }
}
