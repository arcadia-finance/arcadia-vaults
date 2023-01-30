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

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
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
        vm.expectRevert("Ownable: caller is not the owner");
        abstractPricingModule.setRiskManager(newRiskManager);
        vm.stopPrank();

        assertEq(abstractPricingModule.riskManager(), creatorAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_isAllowListed_Positive(address asset, uint128 maxExposure) public {
        // Given: asset is white listed
        vm.assume(maxExposure > 0);
        abstractPricingModule.setExposure(asset, 0, maxExposure);

        // When: isAllowListed(asset, 0) is called
        // Then: It should return true
        assertTrue(abstractPricingModule.isAllowListed(asset, 0));
    }

    function testSuccess_isAllowListed_Negative(address asset) public {
        // Given: All necessary contracts deployed on setup
        // And: asset is non whitelisted

        // When: isWhiteListed(asset, 0) is called
        // Then: It should return false
        assertTrue(!abstractPricingModule.isAllowListed(asset, 0));
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getRiskVariables_RiskVariablesAreSet(
        address asset,
        uint256 baseCurrency,
        uint16 collateralFactor_,
        uint16 liquidationFactor_
    ) public {
        uint256 slot = stdstore.target(address(abstractPricingModule)).sig(abstractPricingModule.assetRiskVars.selector)
            .with_key(asset).with_key(baseCurrency).find();
        bytes32 loc = bytes32(slot);
        bytes32 value = bytes32(abi.encodePacked(liquidationFactor_, collateralFactor_));
        value = value >> 224;
        vm.store(address(abstractPricingModule), loc, value);

        (uint16 actualCollateralFactor, uint16 actualLiquidationThreshold) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);

        assertEq(actualCollateralFactor, collateralFactor_);
        assertEq(actualLiquidationThreshold, liquidationFactor_);
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

        (uint16 collateralFactor_, uint16 liquidationFactor_) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, 0);
        assertEq(liquidationFactor_, 0);
    }

    function testRevert_setRiskVariables_LiquidationTreshholdOutOfLimits(
        address asset,
        uint256 baseCurrency,
        PricingModule.RiskVars memory riskVars_
    ) public {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.assume(riskVars_.liquidationFactor > RiskConstants.MAX_LIQUIDATION_FACTOR);

        vm.expectRevert("APM_SRV: Liq.Fact not in limits");
        abstractPricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor_, uint16 liquidationFactor_) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, 0);
        assertEq(liquidationFactor_, 0);
    }

    function testSuccess_setRiskVariables(address asset, uint256 baseCurrency, PricingModule.RiskVars memory riskVars_)
        public
    {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.assume(riskVars_.liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);

        abstractPricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor_, uint16 liquidationFactor_) =
            abstractPricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, riskVars_.collateralFactor);
        assertEq(liquidationFactor_, riskVars_.liquidationFactor);
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
        vm.expectRevert("APM_SBRV: BaseCur. not in limits");
        abstractPricingModule.setBatchRiskVariables(riskVarInputs);
        vm.stopPrank();
    }

    function testSuccess_setBatchRiskVariables(PricingModule.RiskVarInput[2] memory riskVarInputs) public {
        vm.assume(riskVarInputs[0].baseCurrency != riskVarInputs[1].baseCurrency);
        stdstore.target(address(mainRegistry)).sig(mainRegistry.baseCurrencyCounter.selector).checked_write(
            type(uint256).max
        );

        for (uint256 i; i < riskVarInputs_.length; ++i) {
            riskVarInputs_.push(riskVarInputs[i]);
            vm.assume(riskVarInputs_[i].collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
            vm.assume(riskVarInputs_[i].liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        }

        vm.startPrank(creatorAddress);
        abstractPricingModule.setBatchRiskVariables(riskVarInputs_);

        for (uint256 i; i < riskVarInputs_.length; ++i) {
            (uint16 collateralFactor_, uint16 liquidationFactor_) =
                abstractPricingModule.getRiskVariables(riskVarInputs_[i].asset, riskVarInputs_[i].baseCurrency);
            assertEq(collateralFactor_, riskVarInputs_[i].collateralFactor);
            assertEq(liquidationFactor_, riskVarInputs_[i].liquidationFactor);
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
        vm.expectRevert("APM_SRVFA: BaseCur not in limits");
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

        for (uint256 i; i < riskVarInputs.length; ++i) {
            riskVarInputs_.push(riskVarInputs[i]);
            vm.assume(riskVarInputs[i].collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
            vm.assume(riskVarInputs[i].liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        }

        vm.startPrank(creatorAddress);
        abstractPricingModule.setRiskVariablesForAsset(asset, riskVarInputs_);

        for (uint256 i; i < riskVarInputs.length; ++i) {
            (uint16 collateralFactor_, uint16 liquidationFactor_) =
                abstractPricingModule.getRiskVariables(asset, riskVarInputs[i].baseCurrency);
            assertEq(collateralFactor_, riskVarInputs[i].collateralFactor);
            assertEq(liquidationFactor_, riskVarInputs[i].liquidationFactor);
        }
    }

    function testRevert_setExposureOfAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint128 maxExposure
    ) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        abstractPricingModule.setExposureOfAsset(asset, maxExposure);
        vm.stopPrank();
    }

    function testSuccess_setExposureOfAsset(address asset, uint128 maxExposure) public {
        vm.prank(creatorAddress);
        abstractPricingModule.setExposureOfAsset(asset, maxExposure);

        (uint128 actualMaxExposure,) = abstractPricingModule.exposure(asset);
        assertEq(actualMaxExposure, maxExposure);
    }

    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress_, address asset, uint128 amount)
        public
    {
        vm.assume(unprivilegedAddress_ != address(mainRegistry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        abstractPricingModule.processDeposit(asset, 0, amount);
        vm.stopPrank();
    }

    function testRevert_processDeposit_OverExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure
    ) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount > maxExposure);
        abstractPricingModule.setExposure(asset, exposure, maxExposure);

        vm.startPrank(address(mainRegistry));
        vm.expectRevert("APM_PD: Exposure not in limits");
        abstractPricingModule.processDeposit(address(asset), 0, amount);
        vm.stopPrank();
    }

    function testSuccess_processDeposit(address asset, uint128 exposure, uint128 amount, uint128 maxExposure) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount <= maxExposure);
        abstractPricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistry));
        abstractPricingModule.processDeposit(address(asset), 0, amount);

        (, uint128 actualExposure) = abstractPricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure + amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testRevert_processWithdrawal_NonMainRegistry(address unprivilegedAddress_, address asset, uint128 amount)
        public
    {
        vm.assume(unprivilegedAddress_ != address(mainRegistry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        abstractPricingModule.processWithdrawal(asset, amount);
        vm.stopPrank();
    }

    function testSuccess_processWithdrawal(address asset, uint128 exposure, uint128 amount, uint128 maxExposure)
        public
    {
        vm.assume(maxExposure >= exposure);
        vm.assume(exposure >= amount);
        abstractPricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistry));
        abstractPricingModule.processWithdrawal(asset, amount);

        (, uint128 actualExposure) = abstractPricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure - amount;

        assertEq(actualExposure, expectedExposure);
    }
}
