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

    function setRiskVariablesForAsset(address asset, RiskVarInput[] memory riskVarInputs) public {
        _setRiskVariablesForAsset(asset, riskVarInputs);
    }

    function setRiskVariables(address asset, uint256 basecurrency, RiskVars memory riskVars_) public {
        _setRiskVariables(asset, basecurrency, riskVars_);
    }
}

contract AbstractPricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    AbstractPricingModuleExtension public abstractPricingModule;

    PricingModule.RiskVarInput[] riskVarInputs_;

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

    /*///////////////////////////////////////////////////////////////
                       DEPLOYMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_deployment(address mainRegistry_, address oracleHub_) public {
        vm.prank(creatorAddress);
        abstractPricingModule = new AbstractPricingModuleExtension(
            mainRegistry_,
            oracleHub_
        );

        assertEq(abstractPricingModule.mainRegistry(), mainRegistry_);
        assertEq(abstractPricingModule.oracleHub(), oracleHub_);
        assertEq(abstractPricingModule.riskManager(), creatorAddress);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK MANAGER MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_setRiskManager(address newRiskManager) public {
        assertEq(abstractPricingModule.riskManager(), creatorAddress);

        vm.prank(creatorAddress);
        abstractPricingModule.setRiskManager(newRiskManager);

        assertEq(abstractPricingModule.riskManager(), newRiskManager);
    }

    function testRevert_setRiskManager_NonRiskManager(address newRiskManager, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);
        assertEq(abstractPricingModule.riskManager(), creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        abstractPricingModule.setRiskManager(newRiskManager);
        vm.stopPrank();

        assertEq(abstractPricingModule.riskManager(), creatorAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_addToWhiteList_NonOwner(address asset, address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);

        // When: unprivilegedAddress_ calls addToWhiteList
        // Then: addToWhiteList should revert with "Ownable: caller is not the owner"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.addToWhiteList(asset);
        vm.stopPrank();
    }

    function testRevert_addToWhiteList_UnknownAsset(address asset) public {
        // Given: All necessary contracts deployed on setup

        // When: creatorAddress adds asset to the white list
        // Then: addToWhiteList should revert with "APM_ATWL: UNKNOWN_ASSET"
        vm.startPrank(creatorAddress);
        vm.expectRevert("APM_ATWL: UNKNOWN_ASSET");
        abstractPricingModule.addToWhiteList(asset);
        vm.stopPrank();
    }

    function testSuccess_addToWhiteList_NonWhiteListedAsset(address asset) public {
        // Given: asset is in the pricing module
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.inPricingModule.selector).with_key(
            asset
        ).checked_write(true);

        // And: asset is not white listed
        (bool isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(!isWhiteListed);

        // When: creatorAddress adds asset to the white list
        vm.prank(creatorAddress);
        abstractPricingModule.addToWhiteList(asset);

        // Then: asset is white listed
        (isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(isWhiteListed);
    }

    function testSuccess_addToWhiteList_WhiteListedAsset(address asset) public {
        // Given: asset is in the pricing module
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.inPricingModule.selector).with_key(
            asset
        ).checked_write(true);

        // And: asset is white listed
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.isAssetAddressWhiteListed.selector)
            .with_key(asset).checked_write(true);

        // When: creatorAddress adds asset to the white list
        vm.prank(creatorAddress);
        abstractPricingModule.addToWhiteList(asset);

        // Then: asset is white listed
        (bool isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(isWhiteListed);
    }

    function testRevert_removeFromWhiteList_NonOwner(address asset, address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not creatorAddress
        vm.assume(unprivilegedAddress_ != creatorAddress);

        // When: unprivilegedAddress_ calls addToWhiteList
        // Then: removeFromWhiteList should revert with "Ownable: caller is not the owner"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.removeFromWhiteList(asset);
        vm.stopPrank();
    }

    function testRevert_removeFromWhiteList_UnknownAsset(address asset) public {
        // Given: All necessary contracts deployed on setup

        // When: creatorAddress adds asset to the white list
        // Then: removeFromWhiteList should revert with "APM_RFWL: UNKNOWN_ASSET"
        vm.startPrank(creatorAddress);
        vm.expectRevert("APM_RFWL: UNKNOWN_ASSET");
        abstractPricingModule.removeFromWhiteList(asset);
        vm.stopPrank();
    }

    function testSuccess_removeFromWhiteList_NonWhiteListedAsset(address asset) public {
        // Given: asset is in the pricing module
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.inPricingModule.selector).with_key(
            asset
        ).checked_write(true);

        // And: asset is not white listed
        (bool isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(!isWhiteListed);

        // When: creatorAddress removes asset from the white list
        vm.prank(creatorAddress);
        abstractPricingModule.removeFromWhiteList(asset);

        // Then: asset is not white listed
        (isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(!isWhiteListed);
    }

    function testSuccess_removeFromWhiteList_WhiteListedAsset(address asset) public {
        // Given: asset is in the pricing module
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.inPricingModule.selector).with_key(
            asset
        ).checked_write(true);

        // And: asset is white listed
        stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.isAssetAddressWhiteListed.selector)
            .with_key(asset).checked_write(true);

        // When: creatorAddress removes asset from the white list
        vm.prank(creatorAddress);
        abstractPricingModule.removeFromWhiteList(asset);

        // Then: asset is not white listed
        (bool isWhiteListed,) = abstractPricingModule.isAssetAddressWhiteListed(asset);
        assertTrue(!isWhiteListed);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getRiskVariables_RiskVariablesAreSet(
        address asset,
        uint256 baseCurrency,
        uint16 collateralFactor,
        uint16 liquidationThreshold
    ) public {
        uint256 slot = stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.assetRiskVars.selector)
            .with_key(asset).with_key(baseCurrency).find();
        bytes32 loc = bytes32(slot);
        bytes32 value = bytes32(abi.encodePacked(liquidationThreshold, collateralFactor));
        value = value >> 224;
        vm.store(address(abstractPricingModule), loc, value);

        (uint16 actualCollateralFactor, uint16 actualLiquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);

        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationThreshold, liquidationThreshold);
    }

    function testSuccess_getRiskVariables_RiskVariablesAreNotSet(address asset, uint256 baseCurrency) public {
        (uint16 actualCollateralFactor, uint16 actualLiquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);

        assertEq(actualCollateralFactor, 0);
        assertEq(actualLiquidationThreshold, 0);
    }

    function testRevert_setRiskVariables_CollateralFactorOutOfLimits(
        address asset,
        uint256 baseCurrency,
        PricingModule.RiskVars memory riskVars_
    ) public {
        vm.assume(riskVars_.collateralFactor > RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.expectRevert("APM_SRV: Coll.Fact not in limits");
        abstractPricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor, uint16 liquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor, 0);
        assertEq(liquidationThreshold, 0);
    }

    function testRevert_setRiskVariables_LiquidationTreshholdOutOfLimits(
        address asset,
        uint256 baseCurrency,
        PricingModule.RiskVars memory riskVars_
    ) public {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.assume(
            riskVars_.liquidationThreshold > RiskConstants.MAX_LIQUIDATION_THRESHOLD
                || riskVars_.liquidationThreshold < RiskConstants.MIN_LIQUIDATION_THRESHOLD
        );

        vm.expectRevert("APM_SRV: Liq.Thres not in limits");
        abstractPricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor, uint16 liquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor, 0);
        assertEq(liquidationThreshold, 0);
    }

    function testSuccess_setRiskVariables(address asset, uint256 baseCurrency, PricingModule.RiskVars memory riskVars_)
        public
    {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.assume(
            riskVars_.liquidationThreshold <= RiskConstants.MAX_LIQUIDATION_THRESHOLD
                && riskVars_.liquidationThreshold >= RiskConstants.MIN_LIQUIDATION_THRESHOLD
        );

        abstractPricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor, uint16 liquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor, riskVars_.collateralFactor);
        assertEq(liquidationThreshold, riskVars_.liquidationThreshold);
    }

    function testRevert_setBatchRiskVariables_NonRiskManager(
        PricingModule.RiskVarInput[] memory riskVarInputs,
        address unprivilegedAddress_
    ) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        abstractPricingModule.setBatchRiskVariables(riskVarInputs);
        vm.stopPrank();
    }

    function testRevert_setBatchRiskVariables_BaseCurrencyNotInLimits(
        PricingModule.RiskVarInput[] memory riskVarInputs,
        uint256 baseCurrencyCounter
    ) public {
        vm.assume(riskVarInputs.length > 0);
        vm.assume(riskVarInputs[0].baseCurrency >= baseCurrencyCounter);

        stdstore.target(address(mainRegistry)).sig(mainRegistry.baseCurrencyCounter.selector).checked_write(
            baseCurrencyCounter
        );

        vm.startPrank(creatorAddress);
        vm.expectRevert("APM_SBRV: BaseCurrency not in limits");
        abstractPricingModule.setBatchRiskVariables(riskVarInputs);
        vm.stopPrank();
    }

    function testSuccess_setBatchRiskVariables(PricingModule.RiskVarInput[2] memory riskVarInputs) public {
        vm.assume(riskVarInputs[0].baseCurrency != riskVarInputs[1].baseCurrency);
        stdstore.target(address(mainRegistry)).sig(mainRegistry.baseCurrencyCounter.selector).checked_write(
            type(uint256).max
        );

        for (uint256 i; i < riskVarInputs_.length; i++) {
            riskVarInputs_.push(riskVarInputs[i]);
            vm.assume(riskVarInputs_[i].collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
            vm.assume(
                riskVarInputs_[i].liquidationThreshold <= RiskConstants.MAX_LIQUIDATION_THRESHOLD
                    && riskVarInputs_[i].liquidationThreshold >= RiskConstants.MIN_LIQUIDATION_THRESHOLD
            );
        }

        vm.startPrank(creatorAddress);
        abstractPricingModule.setBatchRiskVariables(riskVarInputs_);

        for (uint256 i; i < riskVarInputs_.length; i++) {
            (uint16 collateralFactor, uint16 liquidationThreshold) =
                abstractPricingModule.getRiskVariables(riskVarInputs_[i].asset, riskVarInputs_[i].baseCurrency);
            assertEq(collateralFactor, riskVarInputs_[i].collateralFactor);
            assertEq(liquidationThreshold, riskVarInputs_[i].liquidationThreshold);
        }
    }

    function testRevert_setRiskVariablesForAsset_BaseCurrencyNotInLimits(
        address asset,
        PricingModule.RiskVarInput[] memory riskVarInputs,
        uint256 baseCurrencyCounter
    ) public {
        vm.assume(riskVarInputs.length > 0);
        vm.assume(riskVarInputs[0].baseCurrency >= baseCurrencyCounter);

        stdstore.target(address(mainRegistry)).sig(mainRegistry.baseCurrencyCounter.selector).checked_write(
            baseCurrencyCounter
        );

        vm.startPrank(creatorAddress);
        vm.expectRevert("APM_SRVFA: BaseCurrency not in limits");
        abstractPricingModule.setRiskVariablesForAsset(asset, riskVarInputs);
        vm.stopPrank();
    }

    function testSuccess_setRiskVariablesForAsset(address asset, PricingModule.RiskVarInput[2] memory riskVarInputs)
        public
    {
        vm.assume(riskVarInputs[0].baseCurrency != riskVarInputs[1].baseCurrency);

        stdstore.target(address(mainRegistry)).sig(mainRegistry.baseCurrencyCounter.selector).checked_write(
            type(uint256).max
        );

        for (uint256 i; i < riskVarInputs.length; i++) {
            riskVarInputs_.push(riskVarInputs[i]);
            vm.assume(riskVarInputs[i].collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
            vm.assume(
                riskVarInputs[i].liquidationThreshold <= RiskConstants.MAX_LIQUIDATION_THRESHOLD
                    && riskVarInputs[i].liquidationThreshold >= RiskConstants.MIN_LIQUIDATION_THRESHOLD
            );
        }

        vm.startPrank(creatorAddress);
        abstractPricingModule.setRiskVariablesForAsset(asset, riskVarInputs_);

        for (uint256 i; i < riskVarInputs.length; i++) {
            (uint16 collateralFactor, uint16 liquidationThreshold) =
                abstractPricingModule.getRiskVariables(asset, riskVarInputs[i].baseCurrency);
            assertEq(collateralFactor, riskVarInputs[i].collateralFactor);
            assertEq(liquidationThreshold, riskVarInputs[i].liquidationThreshold);
        }
    }
}
