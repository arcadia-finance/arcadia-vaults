/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";
import { LendingPool, DebtToken, ERC20 } from "../../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../../lib/arcadia-lending/src/Tranche.sol";

import { ActionMultiCall } from "../actions/MultiCall.sol";
import "../actions/utils/ActionData.sol";
import { MultiActionMock } from "../mockups/MultiActionMock.sol";

contract VaultTestExtension is Vault {
    constructor(address mainReg_, uint16 vaultVersion_) Vault(mainReg_, vaultVersion_) { }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setTrustedCreditor(address trustedCreditor_) public {
        trustedCreditor = trustedCreditor_;
    }

    function setIsTrustedCreditorSet(bool set) public {
        isTrustedCreditorSet = set;
    }

    function setVaultVersion(uint16 version) public {
        vaultVersion = version;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }
}

abstract contract vaultTests is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    VaultTestExtension public vault_;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    bytes3 public emptyBytes3;

    struct Assets {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory), address(liquidator));
        pool.setVaultVersion(1, true);
        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50, 0);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
    }

    //this is a before each
    function setUp() public virtual {
        vm.prank(vaultOwner);
        vault_ = new VaultTestExtension(address(mainRegistry), 1);
    }

    function deployFactory() internal {
        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vault_), Constants.upgradeProof1To2, "");
        vm.stopPrank();

        stdstore.target(address(factory)).sig(factory.isVault.selector).with_key(address(vault_)).checked_write(true);
        stdstore.target(address(factory)).sig(factory.vaultIndex.selector).with_key(address(vault_)).checked_write(10);
        factory.setOwnerOf(vaultOwner, 10);
    }

    function openMarginAccount() internal {
        vm.startPrank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));
        dai.approve(address(vault_), type(uint256).max);
        bayc.setApprovalForAll(address(vault_), true);
        mayc.setApprovalForAll(address(vault_), true);
        dickButs.setApprovalForAll(address(vault_), true);
        interleave.setApprovalForAll(address(vault_), true);
        eth.approve(address(vault_), type(uint256).max);
        link.approve(address(vault_), type(uint256).max);
        snx.approve(address(vault_), type(uint256).max);
        safemoon.approve(address(vault_), type(uint256).max);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function depositEthAndTakeMaxCredit(uint128 amountEth) public returns (uint256) {
        depositERC20InVault(eth, amountEth, vaultOwner);
        vm.startPrank(vaultOwner);
        uint256 remainingCredit = vault_.getFreeMargin();
        pool.borrow(uint128(remainingCredit), address(vault_), vaultOwner, emptyBytes3);
        vm.stopPrank();

        return remainingCredit;
    }

    function depositERC20InVault(ERC20Mock token, uint128 amount, address sender)
        public
        virtual
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositEthInVault(uint8 amount, address sender) public returns (Assets memory assetInfo) {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        assetInfo = Assets({ assetAddresses: assetAddresses, assetIds: assetIds, assetAmounts: assetAmounts });
    }

    function depositLinkInVault(uint8 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositBaycInVault(uint128[] memory tokenIds, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (bayc.getOwnerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            bayc.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(bayc);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
        }

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function generateERC721DepositList(uint8 length)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](length);

        assetIds = new uint256[](length);

        assetAmounts = new uint256[](length);

        assetTypes = new uint256[](length);

        uint256 id = 10;
        for (uint256 i; i < length; ++i) {
            vm.prank(tokenCreatorAddress);
            bayc.mint(vaultOwner, id);
            assetAddresses[i] = address(bayc);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
            ++id;
        }
    }
}

contract DeploymentTest is vaultTests {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        assertEq(vault_.owner(), vaultOwner);
        assertEq(vault_.registry(), address(mainRegistry));
        assertEq(vault_.vaultVersion(), 1);
        assertEq(vault_.baseCurrency(), address(0));
    }
}

/* ///////////////////////////////////////////////////////////////
                    VAULT MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract VaultManagementTest is vaultTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        vm.prank(vaultOwner);
        vault_ = new VaultTestExtension(address(mainRegistry), 1);
    }

    function testRevert_initialize_AlreadyInitialized() public {
        vm.expectRevert("V_I: Already initialized!");
        vault_.initialize(vaultOwner, address(mainRegistry), 1, address(0));
    }

    function testRevert_initialize_InvalidVersion() public {
        vault_.setVaultVersion(0);
        vault_.setOwner(address(0));

        vm.expectRevert("V_I: Invalid vault version");
        vault_.initialize(vaultOwner, address(mainRegistry), 0, address(0));
    }

    function testSuccess_initialize(address owner_, uint16 vaultVersion_) public {
        vm.assume(vaultVersion_ > 0);

        vault_.setVaultVersion(0);
        vault_.setOwner(address(0));

        vault_.initialize(owner_, address(mainRegistry), vaultVersion_, address(0));

        assertEq(vault_.owner(), owner_);
        assertEq(vault_.registry(), address(mainRegistry));
        assertEq(vault_.vaultVersion(), vaultVersion_);
        assertEq(vault_.baseCurrency(), address(0));
    }

    function testSuccess_upgradeVault(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        //TrustedCreditor is set
        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        vm.prank(creatorAddress);
        pool.setVaultVersion(newVersion, true);

        vm.prank(address(factory));
        vault_.upgradeVault(newImplementation, newRegistry, newVersion, data);

        uint16 expectedVersion = vault_.vaultVersion();

        assertEq(expectedVersion, newVersion);
    }

    function testRevert_upgradeVault_byNonOwner(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        address nonOwner,
        bytes calldata data
    ) public {
        vm.assume(nonOwner != address(factory));

        vm.startPrank(nonOwner);
        vm.expectRevert("V: Only Factory");
        vault_.upgradeVault(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testRevert_upgradeVault_InvalidVaultVersion(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        vm.assume(newVersion != 1);

        //TrustedCreditor is set
        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        vm.startPrank(address(factory));
        vm.expectRevert("V_UV: Invalid vault version");
        vault_.upgradeVault(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
                OWNERSHIP MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract OwnershipManagementTest is vaultTests {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(vaultOwner, vault_.owner());

        vm.startPrank(sender);
        vm.expectRevert("V: Only Factory");
        vault_.transferOwnership(to);
        vm.stopPrank();

        assertEq(vaultOwner, vault_.owner());
    }

    function testRevert_transferOwnership_InvalidRecipient() public {
        assertEq(vaultOwner, vault_.owner());

        vm.startPrank(address(factory));
        vm.expectRevert("V_TO: INVALID_RECIPIENT");
        vault_.transferOwnership(address(0));
        vm.stopPrank();

        assertEq(vaultOwner, vault_.owner());
    }

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        assertEq(vaultOwner, vault_.owner());

        vm.prank(address(factory));
        vault_.transferOwnership(to);

        assertEq(to, vault_.owner());
    }
}

/* ///////////////////////////////////////////////////////////////
                BASE CURRENCY LOGIC
/////////////////////////////////////////////////////////////// */
contract BaseCurrencyLogicTest is vaultTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        deployFactory();
        //openMarginAccount();
    }

    function testSuccess_setBaseCurrency() public {
        vm.prank(vaultOwner);
        vault_.setBaseCurrency(address(eth));

        assertEq(vault_.baseCurrency(), address(eth));
    }

    function testRevert_setBaseCurrency_NonAuthorized(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != vaultOwner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("V: Only Owner");
        vault_.setBaseCurrency(address(eth));
        vm.stopPrank();
    }

    function testRevert_setBaseCurrency_TrustedCreditorSet() public {
        openMarginAccount();

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_SBC: Trusted Creditor Set");
        vault_.setBaseCurrency(address(eth));
        vm.stopPrank();

        assertEq(vault_.baseCurrency(), address(dai));
    }

    function testRevert_setBaseCurrency_BaseCurrencyNotFound(address baseCurrency_) public {
        vm.assume(baseCurrency_ != address(0));
        vm.assume(baseCurrency_ != address(eth));
        vm.assume(baseCurrency_ != address(dai));

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_SBC: baseCurrency not found");
        vault_.setBaseCurrency(baseCurrency_);
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
            MARGIN ACCOUNT SETTINGS
/////////////////////////////////////////////////////////////// */
contract MarginAccountSettingsTest is vaultTests {
    using stdStorage for StdStorage;

    TrustedCreditorMock trustedCreditor;

    function setUp() public override {
        super.setUp();
        deployFactory();
    }

    function testRevert_openTrustedMarginAccount_NonOwner(address unprivilegedAddress_, address trustedCreditor_)
        public
    {
        vm.assume(unprivilegedAddress_ != vaultOwner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("V: Only Owner");
        vault_.openTrustedMarginAccount(trustedCreditor_);
        vm.stopPrank();
    }

    function testRevert_openTrustedMarginAccount_AlreadySet(address trustedCreditor_) public {
        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_OTMA: ALREADY SET");
        vault_.openTrustedMarginAccount(trustedCreditor_);
        vm.stopPrank();
    }

    function testRevert_openTrustedMarginAccount_OpeningMarginAccountFails() public {
        trustedCreditor = new TrustedCreditorMock();

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_OTMA: Invalid Version");
        vault_.openTrustedMarginAccount(address(trustedCreditor));
        vm.stopPrank();
    }

    function testSuccess_openTrustedMarginAccount_DifferentBaseCurrency() public {
        assertEq(vault_.baseCurrency(), address(0));

        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        assertEq(vault_.liquidator(), address(liquidator));
        assertEq(vault_.trustedCreditor(), address(pool));
        assertEq(vault_.baseCurrency(), address(dai));
        assertTrue(vault_.isTrustedCreditorSet());
    }

    function testSuccess_openTrustedMarginAccount_SameBaseCurrency() public {
        //Set BaseCurrency to dai
        stdstore.target(address(vault_)).sig(vault_.baseCurrency.selector).checked_write(address(dai));
        assertEq(vault_.baseCurrency(), address(dai));

        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        assertEq(vault_.liquidator(), address(liquidator));
        assertEq(vault_.trustedCreditor(), address(pool));
        assertEq(vault_.baseCurrency(), address(dai));
        assertTrue(vault_.isTrustedCreditorSet());
    }

    function testRevert_closeTrustedMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != vaultOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("V: Only Owner");
        vault_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testRevert_closeTrustedMarginAccount_NonSetTrustedMarginAccount() public {
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_CTMA: NOT SET");
        vault_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testRevert_closeTrustedMarginAccount_OpenPosition() public {
        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        bytes32 addDebt = bytes32(abi.encode(1));
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(addDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(addDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).checked_write(addDebt);

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_CTMA: NON-ZERO OPEN POSITION");
        vault_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testSuccess_closeTrustedMarginAccount() public {
        vm.prank(vaultOwner);
        vault_.openTrustedMarginAccount(address(pool));

        vm.prank(vaultOwner);
        vault_.closeTrustedMarginAccount();

        assertTrue(!vault_.isTrustedCreditorSet());
        assertTrue(vault_.trustedCreditor() == address(0));
    }
}

/* ///////////////////////////////////////////////////////////////
                    MARGIN REQUIREMENTS
/////////////////////////////////////////////////////////////// */
contract MarginRequirementsTest is vaultTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testSuccess_isVaultHealthy_debtIncrease_InsufficientMargin(
        uint8 depositAmount,
        uint128 marginIncrease,
        uint128 usedMargin,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for basecurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Vault has already used margin
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).checked_write(usedMargin);

        // And: Eth is deposited in the Vault
        depositEthInVault(depositAmount, vaultOwner);

        // And: There is insufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue < uint256(usedMargin) + marginIncrease);
        vm.assume(depositAmount > 0); // Devision by 0

        // When: An Authorised protocol tries to take more margin against the vault
        vm.prank(address(pool));
        (bool success,) = vault_.isVaultHealthy(marginIncrease, 0);

        // Then: The action is not succesfull
        assertTrue(!success);
    }

    function testSuccess_isVaultHealthy_debtIncrease_SufficientMargin(
        uint8 depositAmount,
        uint128 marginIncrease,
        uint128 usedMargin,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for basecurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Vault has already used margin
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).checked_write(usedMargin);

        // And: Eth is deposited in the Vault
        depositEthInVault(depositAmount, vaultOwner);

        // And: There is sufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue >= uint256(usedMargin) + marginIncrease);
        vm.assume(depositAmount > 0); // Devision by 0

        // When: An Authorised protocol tries to take more margin against the vault
        vm.prank(address(pool));
        (bool success,) = vault_.isVaultHealthy(marginIncrease, 0);

        // Then: The action is succesfull
        assertTrue(success);
    }

    function testSuccess_isVaultHealthy_totalOpenDebt_InsufficientMargin(
        uint8 depositAmount,
        uint128 totalOpenDebt,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for basecurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Eth is deposited in the Vault
        depositEthInVault(depositAmount, vaultOwner);

        // And: There is insufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue < totalOpenDebt);
        vm.assume(depositAmount > 0); // Devision by 0

        // When: An Authorised protocol tries to take more margin against the vault
        vm.prank(address(pool));
        (bool success,) = vault_.isVaultHealthy(0, totalOpenDebt);

        // Then: The action is not succesfull
        assertTrue(!success);
    }

    function testSuccess_isVaultHealthy_totalOpenDebt_SufficientMargin(
        uint8 depositAmount,
        uint128 totalOpenDebt,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for basecurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Eth is deposited in the Vault
        depositEthInVault(depositAmount, vaultOwner);

        // And: There is sufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue >= totalOpenDebt);
        vm.assume(depositAmount > 0); // Devision by 0

        // When: An Authorised protocol tries to take more margin against the vault
        vm.prank(address(pool));
        (bool success,) = vault_.isVaultHealthy(0, totalOpenDebt);

        // Then: The action is succesfull
        assertTrue(success);
    }

    function testSuccess_getVaultValue(uint8 depositAmount) public {
        depositEthInVault(depositAmount, vaultOwner);

        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals);
        uint256 actualValue = vault_.getVaultValue(address(dai));

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getVaultValue_GasUsage(uint8 depositAmount, uint128[] calldata tokenIds) public {
        vm.assume(tokenIds.length <= 5);
        vm.assume(depositAmount > 0);
        depositEthInVault(depositAmount, vaultOwner);
        depositLinkInVault(depositAmount, vaultOwner);
        depositBaycInVault(tokenIds, vaultOwner);

        uint256 gasStart = gasleft();
        vault_.getVaultValue(address(dai));
        uint256 gasAfter = gasleft();
        emit log_int(int256(gasStart - gasAfter));
        assertLt(gasStart - gasAfter, 200_000);
    }

    function testSuccess_getLiquidationValue(uint8 depositAmount) public {
        depositEthInVault(depositAmount, vaultOwner);

        uint16 liqFactor_ = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * liqFactor_ / 100;

        uint256 actualValue = vault_.getLiquidationValue();

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getCollateralValue(uint8 depositAmount) public {
        depositEthInVault(depositAmount, vaultOwner);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFactor_ / 100;

        uint256 actualValue = vault_.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getUsedMargin(uint256 usedMargin) public {
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).checked_write(usedMargin);

        assertEq(usedMargin, vault_.getUsedMargin());
    }

    function testSuccess_getFreeMargin_ZeroInitially() public {
        uint256 remainingCredit = vault_.getFreeMargin();
        assertEq(remainingCredit, 0);
    }

    function testSuccess_getFreeMargin_AfterFirstDeposit(uint8 amount) public {
        depositEthInVault(amount, vaultOwner);

        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amount
            / 10 ** (18 - Constants.daiDecimals);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 expectedRemaining = (depositValue * collFactor_) / 100;
        assertEq(expectedRemaining, vault_.getFreeMargin());
    }

    function testSuccess_getFreeMargin_AfterTopUp(uint8 amountEth, uint8 amountLink, uint128[] calldata tokenIds)
        public
    {
        vm.assume(tokenIds.length < 10 && tokenIds.length > 1);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        depositEthInVault(amountEth, vaultOwner);
        uint256 depositValueEth = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth;
        assertEq((depositValueEth / 10 ** (18 - Constants.daiDecimals) * collFactor_) / 100, vault_.getFreeMargin());

        depositLinkInVault(amountLink, vaultOwner);
        uint256 depositValueLink =
            ((Constants.WAD * rateLinkToUsd) / 10 ** Constants.oracleLinkToUsdDecimals) * amountLink;
        assertEq(
            ((depositValueEth + depositValueLink) / 10 ** (18 - Constants.daiDecimals) * collFactor_) / 100,
            vault_.getFreeMargin()
        );

        (, uint256[] memory assetIds,) = depositBaycInVault(tokenIds, vaultOwner);
        uint256 depositBaycValue = (
            (Constants.WAD * rateWbaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleEthToUsdDecimals + Constants.oracleWbaycToEthDecimals)
        ) * assetIds.length;
        assertEq(
            ((depositValueEth + depositValueLink + depositBaycValue) / 10 ** (18 - Constants.daiDecimals) * collFactor_)
                / 100,
            vault_.getFreeMargin()
        );
    }

    function testSuccess_getFreeMargin_AfterTakingCredit(uint8 amountEth, uint128 amountCredit) public {
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
            / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume((depositValue * collFactor_) / 100 > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);

        uint256 actualRemainingCredit = vault_.getFreeMargin();
        uint256 expectedRemainingCredit = (depositValue * collFactor_) / 100 - amountCredit;

        assertEq(expectedRemainingCredit, actualRemainingCredit);
    }

    function testSuccess_getFreeMargin_NoOverflows(uint128 amountEth, uint8 factor) public {
        vm.assume(amountEth < 10 * 10 ** 9 * 10 ** 18);
        vm.assume(amountEth > 0);

        depositERC20InVault(eth, amountEth, vaultOwner);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.prank(vaultOwner);
        pool.borrow((((amountEth * collFactor_) / 100) * factor) / 255, address(vault_), vaultOwner, emptyBytes3);

        uint256 currentValue = vault_.getVaultValue(address(dai));
        uint256 openDebt = vault_.getUsedMargin();

        uint256 maxAllowedCreditLocal;
        uint256 remainingCreditLocal;
        //gas: cannot overflow unless currentValue is more than
        // 1.15**57 *10**18 decimals, which is too many billions to write out
        maxAllowedCreditLocal = (currentValue * collFactor_) / 100;

        remainingCreditLocal = maxAllowedCreditLocal > openDebt ? maxAllowedCreditLocal - openDebt : 0;

        uint256 remainingCreditFetched = vault_.getFreeMargin();

        //remainingCreditFetched has a lot of unchecked operations
        //-> we check that the checked operations never reverts and is
        //always equal to the unchecked operations
        assertEq(remainingCreditLocal, remainingCreditFetched);
    }
}

/* ///////////////////////////////////////////////////////////////
                    LIQUIDATION LOGIC
/////////////////////////////////////////////////////////////// */
contract LiquidationLogicTest is vaultTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testRevert_liquidateVault_NotAuthorized(address unprivilegedAddress_, uint128 openDebt) public {
        vm.assume(unprivilegedAddress_ != address(liquidator));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("V_LV: Only Liquidator");
        vault_.liquidateVault(openDebt);
        vm.stopPrank();
    }

    function testRevert_liquidateVault_VaultIsHealthy() public {
        vm.startPrank(address(liquidator));
        vm.expectRevert("V_LV: Vault is healthy");
        vault_.liquidateVault(0);
        vm.stopPrank();
    }

    function testSuccess_liquidateVault(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(liquidator));
        (address originalOwner, address baseCurrency, address trustedCreditor) = vault_.liquidateVault(openDebt);

        assertEq(originalOwner, vaultOwner);
        assertEq(baseCurrency, address(dai));
        assertEq(trustedCreditor, address(pool));

        assertEq(vault_.owner(), address(liquidator));
        assertEq(vault_.isTrustedCreditorSet(), false);
        assertEq(vault_.trustedCreditor(), address(0));

        uint256 index = factory.vaultIndex(address(vault_));
        assertEq(factory.ownerOf(index), address(liquidator));
    }
}

/*///////////////////////////////////////////////////////////////
                ASSET MANAGEMENT LOGIC
///////////////////////////////////////////////////////////////*/
contract VaultActionTest is vaultTests {
    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    VaultTestExtension public proxy_;
    TrustedCreditorMock public trustedCreditor;

    function depositERC20InVault(ERC20Mock token, uint128 amount, address sender)
        public
        override
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        token.balanceOf(0x0000000000000000000000000000000000000006);

        vm.startPrank(sender);
        token.approve(address(proxy_), amount);
        proxy_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        deployFactory();

        action = new ActionMultiCall(address(mainRegistry));
        deal(address(eth), address(action), 1000 * 10 ** 20, false);

        vm.startPrank(creatorAddress);
        vault = new VaultTestExtension(address(mainRegistry), 1);
        factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeProof1To2, "");
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        proxyAddr = factory.createVault(12_345_678, 0, address(0));
        proxy_ = VaultTestExtension(proxyAddr);
        vm.stopPrank();

        depositERC20InVault(eth, 1000 * 10 ** 18, vaultOwner);
        vm.startPrank(creatorAddress);
        mainRegistry.setAllowedAction(address(action), true);

        trustedCreditor = new TrustedCreditorMock();

        vm.stopPrank();
    }

    function testRevert_setAssetManager_NonOwner(address nonOwner, address assetManager, bool value) public {
        vm.assume(nonOwner != vaultOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("V: Only Owner");
        vault_.setAssetManager(assetManager, value);
        vm.stopPrank();
    }

    function testSuccess_setAssetManager(address assetManager, bool startValue, bool endvalue) public {
        vm.prank(vaultOwner);
        vault_.setAssetManager(assetManager, startValue);
        assertEq(vault_.isAssetManager(vaultOwner, assetManager), startValue);

        vm.prank(vaultOwner);
        vault_.setAssetManager(assetManager, endvalue);
        assertEq(vault_.isAssetManager(vaultOwner, assetManager), endvalue);
    }

    function testRevert_vaultManagementAction_NonAssetManager(address sender, address assetManager) public {
        vm.assume(sender != vaultOwner);
        vm.assume(sender != assetManager);
        vm.assume(sender != address(0));

        vm.prank(vaultOwner);
        proxy_.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("V: Only Asset Manager");
        proxy_.vaultManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_vaultManagementAction_OwnerChanged(address assetManager) public {
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received

        vm.prank(vaultOwner);
        proxy_.setAssetManager(assetManager, true);

        vm.prank(vaultOwner);
        factory.safeTransferFrom(vaultOwner, newOwner, address(proxy_));

        vm.startPrank(assetManager);
        vm.expectRevert("V: Only Asset Manager");
        proxy_.vaultManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_vaultManagementAction_actionNotAllowed(address action_) public {
        vm.assume(action_ != address(action));

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_VMA: Action not allowed");
        proxy_.vaultManagementAction(action_, new bytes(0));
        vm.stopPrank();
    }

    function testRevert_vaultManagementAction_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > proxy_.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        uint256[] memory assetTypes = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts, assetTypes) = generateERC721DepositList(arrLength);

        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });

        ActionData memory assetDataIn = ActionData({
            assets: assetAddresses,
            assetIds: assetIds,
            assetAmounts: assetAmounts,
            assetTypes: assetTypes,
            actionBalances: new uint256[](0)
        });

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        //Already sent asset to action contract
        uint256 id = 10;
        for (uint256 i; i < arrLength; ++i) {
            vm.prank(vaultOwner);
            bayc.transferFrom(vaultOwner, address(action), id);
            ++id;
        }
        vm.prank(address(action));
        bayc.setApprovalForAll(address(proxy_), true);

        vm.prank(vaultOwner);
        vm.expectRevert("V_D: Too many assets");
        proxy_.vaultManagementAction(address(action), callData);
    }

    function testSuccess_vaultManagementAction_Owner(uint128 debtAmount) public {
        multiActionMock = new MultiActionMock();

        vm.prank(vaultOwner);
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + (uint256(debtAmount) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        link.mint(address(multiActionMock), 1000 * 10 ** 18 + debtAmount * ethToLinkRatio);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(vaultOwner);
        proxy_.vaultManagementAction(address(action), callData);
        vm.stopPrank();
    }

    function testSuccess_vaultManagementAction_Assetmanager(uint128 debtAmount, address assetManager) public {
        vm.assume(vaultOwner != assetManager);
        multiActionMock = new MultiActionMock();

        vm.prank(vaultOwner);
        proxy_.setBaseCurrency(address(eth));

        vm.prank(vaultOwner);
        proxy_.setAssetManager(assetManager, true);

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + (uint256(debtAmount) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        link.mint(address(multiActionMock), 1000 * 10 ** 18 + debtAmount * ethToLinkRatio);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(vaultOwner);
        proxy_.vaultManagementAction(address(action), callData);
        vm.stopPrank();
    }

    function testRevert_vaultManagementAction_InsufficientReturned(uint128 debtAmount) public {
        vm.assume(debtAmount > 0);

        multiActionMock = new MultiActionMock();

        vm.prank(vaultOwner);
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + (uint256(debtAmount) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            0
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_VMA: coll. value too low");
        proxy_.vaultManagementAction(address(action), callData);
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
            ASSET DEPOSIT/WITHDRAWN LOGIC
/////////////////////////////////////////////////////////////// */
contract AssetManagementTest is vaultTests {
    using stdStorage for StdStorage;

    VaultTestExtension public vault2;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testRevert_deposit_NonOwner(address sender) public {
        vm.assume(sender != vaultOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10 ** Constants.ethDecimals;

        vm.startPrank(sender);
        vm.expectRevert("V: Only Owner");
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > vault_.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        vm.prank(vaultOwner);
        vm.expectRevert("V_D: Too many assets");
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testRevert_deposit_tooManyAssetsNotAtOnce(uint8 arrLength) public {
        vm.assume(uint256(arrLength) + 1 > vault_.ASSET_LIMIT() && arrLength < 50);

        //deposit a single asset first
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10 ** Constants.ethDecimals;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        assertEq(vault_.erc20Stored(0), address(eth));
        assertEq(vault_.erc20Balances(address(eth)), eth.balanceOf(address(vault_)));

        //then try to go over the asset limit
        assetAddresses = new address[](arrLength);

        assetIds = new uint256[](arrLength);

        assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        vm.prank(vaultOwner);
        vm.expectRevert("V_D: Too many assets");
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_deposit_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));
        vm.assume(addrLen <= vault_.ASSET_LIMIT() && idLen <= vault_.ASSET_LIMIT() && amountLen <= vault_.ASSET_LIMIT());

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_D: Length mismatch");
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_ERC20IsNotWhitelisted(address inputAddr) public {
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));
        vm.assume(inputAddr != address(dai));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        vm.startPrank(vaultOwner);
        vm.expectRevert();
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_ERC721IsNotWhitelisted(address inputAddr, uint256 id) public {
        vm.assume(inputAddr != address(dai));
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(vaultOwner);
        vm.expectRevert();
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);

        mainRegistry.setAssetType(address(eth), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_D: Unknown asset type");
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testSuccess_deposit_ZeroAmount() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 0;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        (uint256 erc20Len,,,) = vault_.getLengths();

        assertEq(erc20Len, 0);
    }

    function testSuccess_deposit_SingleERC20(uint16 amount) public {
        vm.assume(amount > 0);
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        assertEq(vault_.erc20Stored(0), address(eth));
        assertEq(vault_.erc20Balances(address(eth)), eth.balanceOf(address(vault_)));
    }

    function testSuccess_deposit_MultipleSameERC20(uint16 amount) public {
        vm.assume(amount <= 50_000);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        vm.startPrank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        (uint256 erc20StoredDuring,,,) = vault_.getLengths();

        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        (uint256 erc20StoredAfter,,,) = vault_.getLengths();
        vm.stopPrank();

        assertEq(erc20StoredDuring, erc20StoredAfter);
        assertEq(vault_.erc20Balances(address(eth)), eth.balanceOf(address(vault_)));
    }

    function testSuccess_deposit_SingleERC721() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(vault_.erc721Stored(0), address(bayc));
    }

    function testSuccess_deposit_MultipleERC721() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(vault_.erc721Stored(0), address(bayc));
        (, uint256 erc721LengthFirst,,) = vault_.getLengths();
        assertEq(erc721LengthFirst, 1);

        assetIds[0] = 3;
        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(vault_.erc721Stored(1), address(bayc));
        (, uint256 erc721LengthSecond,,) = vault_.getLengths();
        assertEq(erc721LengthSecond, 2);

        assertEq(vault_.erc721TokenIds(0), 1);
        assertEq(vault_.erc721TokenIds(1), 3);
    }

    function testSuccess_deposit_SingleERC1155() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(vault_.erc1155Stored(0), address(interleave));
        assertEq(vault_.erc1155TokenIds(0), 1);
        assertEq(vault_.erc1155Balances(address(interleave), 1), interleave.balanceOf(address(vault_), 1));
    }

    function testSuccess_deposit_ERC20ERC721(uint8 erc20Amount1, uint8 erc20Amount2) public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 2;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20Amount1 * 10 ** Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        assertEq(vault_.erc20Balances(address(eth)), eth.balanceOf(address(vault_)));
        assertEq(vault_.erc20Balances(address(eth)), erc20Amount1 * 10 ** Constants.ethDecimals);
        assertEq(vault_.erc20Balances(address(link)), link.balanceOf(address(vault_)));
        assertEq(vault_.erc20Balances(address(link)), erc20Amount2 * 10 ** Constants.linkDecimals);
    }

    function testSuccess_deposit_ERC20ERC721ERC1155(uint8 erc20Amount1, uint8 erc20Amount2, uint8 erc1155Amount)
        public
    {
        address[] memory assetAddresses = new address[](4);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);
        assetAddresses[3] = address(interleave);

        uint256[] memory assetIds = new uint256[](4);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;
        assetIds[3] = 1;

        uint256[] memory assetAmounts = new uint256[](4);
        assetAmounts[0] = erc20Amount1 * 10 ** Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;
        assetAmounts[3] = erc1155Amount;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        assertEq(vault_.erc20Balances(address(eth)), eth.balanceOf(address(vault_)));
        assertEq(vault_.erc20Balances(address(eth)), erc20Amount1 * 10 ** Constants.ethDecimals);
        assertEq(vault_.erc20Balances(address(link)), link.balanceOf(address(vault_)));
        assertEq(vault_.erc20Balances(address(link)), erc20Amount2 * 10 ** Constants.linkDecimals);
        assertEq(vault_.erc1155Balances(address(interleave), 1), interleave.balanceOf(address(vault_), 1));
        assertEq(vault_.erc1155Balances(address(interleave), 1), erc1155Amount);
    }

    function testRevert_withdraw_NonOwner(uint8 depositAmount, uint8 withdrawalAmount, address sender) public {
        vm.assume(sender != vaultOwner);
        vm.assume(depositAmount > withdrawalAmount);
        Assets memory assetInfo = depositEthInVault(depositAmount, vaultOwner);

        assetInfo.assetAmounts[0] = withdrawalAmount * 10 ** Constants.ethDecimals;
        vm.startPrank(sender);
        vm.expectRevert("V: Only Owner");
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_withdraw_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W: Length mismatch");
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);
        depositEthInVault(5, vaultOwner);

        mainRegistry.setAssetType(address(eth), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W: Unknown asset type");
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_MoreThanMaxExposure(uint256 amountWithdraw, uint128 maxExposure) public {
        vm.assume(amountWithdraw > maxExposure);
        vm.prank(creatorAddress);
        standardERC20PricingModule.setExposureOfAsset(address(eth), maxExposure);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountWithdraw;

        vm.startPrank(vaultOwner);
        vm.expectRevert(stdError.arithmeticError);
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenOneERC721Deposited() public {
        bayc.mint(vaultOwner, 20);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 20;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(vaultOwner);
        bayc.approve(address(vault_), 20);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault2 = new VaultTestExtension(address(mainRegistry), 2);
        stdstore.target(address(factory)).sig(factory.isVault.selector).with_key(address(vault2)).checked_write(true);
        stdstore.target(address(factory)).sig(factory.vaultIndex.selector).with_key(address(vault2)).checked_write(11);
        factory.setOwnerOf(vaultOwner, 11);

        mayc.mint(vaultOwner, 10);
        mayc.mint(vaultOwner, 11);

        assetAddresses[0] = address(mayc);
        assetIds[0] = 10;

        vm.startPrank(vaultOwner);
        mayc.approve(address(vault2), 10);
        vault2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(vaultOwner, address(vault_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W721: Unknown asset");
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenNotOneERC721Deposited(uint128[] calldata tokenIdsDeposit)
        public
    {
        vm.assume(tokenIdsDeposit.length < vault_.ASSET_LIMIT());
        vm.assume(tokenIdsDeposit.length != 1);

        depositBaycInVault(tokenIdsDeposit, vaultOwner);

        vm.prank(vaultOwner);
        vault2 = new VaultTestExtension(address(mainRegistry), 2);
        stdstore.target(address(factory)).sig(factory.isVault.selector).with_key(address(vault2)).checked_write(true);
        stdstore.target(address(factory)).sig(factory.vaultIndex.selector).with_key(address(vault2)).checked_write(11);
        factory.setOwnerOf(vaultOwner, 11);

        mayc.mint(vaultOwner, 10);
        mayc.mint(vaultOwner, 11);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 10;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(vaultOwner);
        mayc.approve(address(vault2), 10);
        vault2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(vaultOwner, address(vault_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W721: Unknown asset");
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC20UnsufficientCollateral(
        uint8 baseAmountDeposit,
        uint24 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public {
        vm.assume(baseAmountCredit > 0);
        vm.assume(baseAmountWithdraw > 0);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint256 amountCredit = baseAmountCredit * 10 ** Constants.daiDecimals;
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 ValueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit <= (valueDeposit * collFactor_) / 100);
        vm.assume(amountCredit > ((valueDeposit - ValueWithdraw) * collFactor_) / 100);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);

        assetInfo.assetAmounts[0] = amountWithdraw;
        vm.expectRevert("V_W: coll. value too low!");
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721UnsufficientCollateral(
        uint128[] calldata tokenIdsDeposit,
        uint8 amountsWithdrawn
    ) public {
        vm.assume(tokenIdsDeposit.length < vault_.ASSET_LIMIT());

        (, uint256[] memory assetIds,) = depositBaycInVault(tokenIdsDeposit, vaultOwner);
        vm.assume(assetIds.length >= amountsWithdrawn && assetIds.length > 1 && amountsWithdrawn > 1);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 rateInUsd = (
            ((Constants.WAD * rateWbaycToEth) / 10 ** Constants.oracleWbaycToEthDecimals) * rateEthToUsd
        ) / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);

        uint128 maxAmountCredit = uint128(((assetIds.length - amountsWithdrawn) * rateInUsd * collFactor_) / 100);

        vm.startPrank(vaultOwner);
        pool.borrow(maxAmountCredit + 1, address(vault_), vaultOwner, emptyBytes3);

        uint256[] memory withdrawalIds = new uint256[](amountsWithdrawn);
        address[] memory withdrawalAddresses = new address[](amountsWithdrawn);
        uint256[] memory withdrawalAmounts = new uint256[](amountsWithdrawn);
        for (uint256 i; i < amountsWithdrawn; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vm.expectRevert("V_W: coll. value too low!");
        vault_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);
    }

    function testSuccess_withdraw_ERC20NoDebt(uint8 baseAmountDeposit) public {
        vm.assume(baseAmountDeposit > 0);
        uint256 valueAmount = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);

        uint256 vaultValue = vault_.getVaultValue(address(dai));

        assertEq(vaultValue, valueAmount);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(vault_), vaultOwner, assetInfo.assetAmounts[0]);
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();

        uint256 vaultValueAfter = vault_.getVaultValue(address(dai));
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            vault_.generateAssetData();
        assertEq(vaultValueAfter, 0);
        assertEq(assetAddresses.length, 0);
        assertEq(assetIds.length, 0);
        assertEq(assetAmounts.length, 0);
    }

    function testSuccess_withdraw_ERC20fterTakingCredit(
        uint8 baseAmountDeposit,
        uint32 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public {
        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 valueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit < ((valueDeposit - valueWithdraw) * collFactor_) / 100);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);
        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);
        assetInfo.assetAmounts[0] = amountWithdraw;
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();

        uint256 actualValue = vault_.getVaultValue(address(dai));
        uint256 expectedValue = valueDeposit - valueWithdraw;

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_withdraw_ERC721AfterTakingCredit(uint128[] calldata tokenIdsDeposit, uint8 baseAmountCredit)
        public
    {
        vm.assume(tokenIdsDeposit.length < vault_.ASSET_LIMIT());
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        (, uint256[] memory assetIds,) = depositBaycInVault(tokenIdsDeposit, vaultOwner);

        uint256 randomAmounts = assetIds.length > 0
            ? uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "testWithrawERC721AfterTakingCredit(uint256[],uint8)", assetIds, baseAmountCredit
                    )
                )
            ) % assetIds.length
            : 0;

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 rateInUsd = (
            ((Constants.WAD * rateWbaycToEth) / 10 ** Constants.oracleWbaycToEthDecimals) * rateEthToUsd
        ) / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);
        uint256 valueOfDeposit = rateInUsd * assetIds.length;

        uint256 valueOfWithdrawal = rateInUsd * randomAmounts;

        vm.assume((valueOfDeposit * collFactor_) / 100 >= amountCredit);
        vm.assume(valueOfWithdrawal < valueOfDeposit);
        vm.assume(amountCredit < ((valueOfDeposit - valueOfWithdrawal) * collFactor_) / 100);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);

        uint256[] memory withdrawalIds = new uint256[](randomAmounts);
        address[] memory withdrawalAddresses = new address[](randomAmounts);
        uint256[] memory withdrawalAmounts = new uint256[](randomAmounts);
        for (uint256 i; i < randomAmounts; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vault_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);

        uint256 actualValue = vault_.getVaultValue(address(dai));
        uint256 expectedValue = valueOfDeposit - valueOfWithdrawal;

        assertEq(expectedValue, actualValue);
    }

    function testRevert_skim_NonOwner(address sender) public {
        vm.assume(sender != vaultOwner);

        vm.startPrank(sender);
        vm.expectRevert("V_S: Only owner can skim");
        vault_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_skim() public {
        depositERC20InVault(eth, 2000, vaultOwner);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(vault_), 1000);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(vault_), vaultOwner, 1000);
        vault_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_nothingToSkim() public {
        depositERC20InVault(eth, 2000, vaultOwner);

        uint256 balanceBeforeStored = vault_.erc20Balances(address(eth));
        uint256 balanceBefore = eth.balanceOf(address(vault_));
        assertEq(balanceBeforeStored, balanceBefore);

        vm.startPrank(vaultOwner);
        vault_.skim(address(eth), 0, 0);
        vm.stopPrank();

        uint256 balancePostStored = vault_.erc20Balances(address(eth));
        uint256 balancePost = eth.balanceOf(address(vault_));
        assertEq(balancePostStored, balancePost);
        assertEq(balancePostStored, balanceBeforeStored);
    }

    function testSuccess_skim_type1_skim(uint128[] calldata tokenIdsDeposit) public {
        vm.assume(tokenIdsDeposit.length < 15 && tokenIdsDeposit.length > 0);
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            depositBaycInVault(tokenIdsDeposit, vaultOwner);

        address[] memory assetAddrOne = new address[](1);
        uint256[] memory assetIdOne = new uint256[](1);
        uint256[] memory assetAmountOne = new uint256[](1);

        assetAddrOne[0] = assetAddresses[0];
        assetIdOne[0] = assetIds[0];
        assetAmountOne[0] = assetAmounts[0];

        vm.startPrank(vaultOwner);
        vault_.withdraw(assetAddrOne, assetIdOne, assetAmountOne);
        bayc.transferFrom(vaultOwner, address(vault_), assetIdOne[0]);

        vault_.skim(assetAddrOne[0], assetIdOne[0], 1);
        vm.stopPrank();

        assertEq(bayc.ownerOf(assetIdOne[0]), vaultOwner);
    }

    function testSuccess_skim_type1_nothingToSkim() public {
        uint128[] memory tokenIdsDeposit = new uint128[](5);
        tokenIdsDeposit[0] = 100;
        tokenIdsDeposit[1] = 200;
        tokenIdsDeposit[2] = 300;
        tokenIdsDeposit[3] = 400;
        tokenIdsDeposit[4] = 500;
        (address[] memory assetAddresses, uint256[] memory assetIds,) = depositBaycInVault(tokenIdsDeposit, vaultOwner);

        uint256 balanceBefore = bayc.balanceOf(address(vault_));

        vm.startPrank(vaultOwner);
        vault_.skim(assetAddresses[0], assetIds[0], 1);
        vm.stopPrank();

        uint256 balancePost = bayc.balanceOf(address(vault_));

        assertEq(balanceBefore, balancePost);
        assertEq(bayc.ownerOf(assetIds[0]), address(vault_));
    }

    function testSuccess_skim_type2_skim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        assetAmounts[0] = 100;
        vm.startPrank(vaultOwner);
        vault_.withdraw(assetAddresses, assetIds, assetAmounts);
        interleave.safeTransferFrom(vaultOwner, address(vault_), 1, 100, "");

        uint256 balanceOwnerBefore = interleave.balanceOf(vaultOwner, 1);

        vault_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balanceOwnerAfter = interleave.balanceOf(vaultOwner, 1);

        assertEq(interleave.balanceOf(address(vault_), 1), vault_.erc1155Balances(address(interleave), 1));
        assertEq(balanceOwnerBefore + 100, balanceOwnerAfter);
    }

    function testSuccess_skim_type2_nothingToSkim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.startPrank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts);

        uint256 balanceBefore = interleave.balanceOf(address(vault_), 1);

        vault_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balancePost = interleave.balanceOf(address(vault_), 1);

        assertEq(balanceBefore, balancePost);
        assertEq(interleave.balanceOf(address(vault_), 1), vault_.erc1155Balances(address(interleave), 1));
    }

    function testSuccess_skim_ether() public {
        vm.deal(address(vault_), 1e21);
        assertEq(address(vault_).balance, 1e21);

        uint256 balanceOwnerBefore = vaultOwner.balance;

        vm.prank(vaultOwner);
        vault_.skim(address(0), 0, 0);

        uint256 balanceOwnerAfter = vaultOwner.balance;

        assertEq(balanceOwnerBefore + 1e21, balanceOwnerAfter);
    }
}

/* ///////////////////////////////////////////////////////////////
                DEPRECIATED TESTS
/////////////////////////////////////////////////////////////// */
//ToDo: All depreciated tests should be moved to Arcadia Lending, to double check that everything is covered there
contract DepreciatedTest is vaultTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    struct debtInfo {
        uint16 collFactor_; //factor 100
        uint8 liqFac; //factor 100
        uint8 baseCurrency;
    }

    function testSuccess_borrow(uint8 baseAmountDeposit, uint8 baseAmountCredit) public {
        uint256 amountDeposit = baseAmountDeposit * 10 ** Constants.daiDecimals;
        vm.assume(amountDeposit > 0);
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume((amountDeposit * collFactor_) / 100 >= amountCredit);
        depositEthInVault(baseAmountDeposit, vaultOwner);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);

        assertEq(dai.balanceOf(vaultOwner), amountCredit);
        assertEq(vault_.getUsedMargin(), amountCredit); //no blocks have passed
    }

    function testRevert_borrow_AsNonOwner(uint8 amountEth, uint128 amountCredit) public {
        vm.assume(amountCredit > 0);
        vm.assume(unprivilegedAddress != vaultOwner);
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth;
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume((depositValue * collFactor_) / 100 > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountCredit, address(vault_), vaultOwner, emptyBytes3);
    }

    function testSuccess_MinCollValueUnchecked() public {
        //uint256 minCollValue;
        //unchecked {minCollValue = uint256(debt._usedMargin) * debt.collFactor_ / 100;}
        assertTrue(uint256(type(uint128).max) * type(uint16).max < type(uint256).max);
    }

    function testSuccess_CheckBaseUnchecked() public {
        uint256 base256 = uint128(1e18) + type(uint64).max + 1;
        uint128 base128 = uint128(uint128(1e18) + type(uint64).max + 1);

        //assert that 1e18 + uint64 < uint128 can't overflow
        assertTrue(base256 == base128);
    }

    //overflows from deltaTimestamp = 894262060268226281981748468
    function testSuccess_CheckExponentUnchecked() public {
        uint256 yearlySeconds = 31_536_000;
        uint256 maxDeltaTimestamp = (uint256(type(uint128).max) * uint256(yearlySeconds)) / 10 ** 18;

        uint256 exponent256 = (maxDeltaTimestamp * 1e18) / yearlySeconds;
        uint128 exponent128 = uint128((maxDeltaTimestamp * uint256(1e18)) / yearlySeconds);

        assertTrue(exponent256 == exponent128);

        uint256 exponent256Overflow = (((maxDeltaTimestamp + 1) * 1e18) / yearlySeconds);
        uint128 exponent128Overflow = uint128(((maxDeltaTimestamp + 1) * 1e18) / yearlySeconds);

        assertTrue(exponent256Overflow != exponent128Overflow);
        assertTrue(exponent128Overflow == exponent256Overflow - type(uint128).max - 1);
    }

    function testSuccess_CheckUnrealisedDebtUnchecked(uint64 base, uint24 deltaTimestamp, uint128 openDebt) public {
        vm.assume(base <= 10 * 10 ** 18); //1000%
        vm.assume(base >= 10 ** 18);
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); //5 year
        vm.assume(openDebt <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        uint256 yearlySeconds = 31_536_000;
        uint128 exponent = uint128(((uint256(deltaTimestamp)) * 1e18) / yearlySeconds);
        vm.assume(LogExpMath.pow(base, exponent) > 0);

        uint256 unRealisedDebt256 = (uint256(openDebt) * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18;
        uint128 unRealisedDebt128 = uint128((openDebt * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18);

        assertEq(unRealisedDebt256, unRealisedDebt128);
    }

    /*
    We assume a situation where the base and exponent are within "logical" (yet extreme) boundries.
    Within this assumption, we let the open debt vary over all possible values within the assumption.
    We then check whether checked uint256 calculations will be equal to unchecked uint128 calcs.
    The assumptions are:
      * 1000% interest rate
      * never synced any debt during 5 years
    **/
    function testSuccess_syncInterests_SyncDebtUnchecked(
        uint64 base,
        uint24 deltaTimestamp,
        uint128 openDebt,
        uint16 additionalDeposit
    ) public {
        vm.assume(base <= 10 * 10 ** 18); //1000%
        vm.assume(base >= 10 ** 18); //No negative interest rate possible
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); //5 year
        vm.assume(additionalDeposit > 0);
        //        vm.assume(additionalDeposit < 10);
        vm.assume(openDebt <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint128 amountEthToDeposit = uint128(
            (
                (openDebt / rateEthToUsd / 10 ** 18) * 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals)
                    * collFactor_
            ) / 100
        ); // This is always zero
        amountEthToDeposit += uint128(additionalDeposit);

        uint256 yearlySeconds = 31_536_000;
        uint128 exponent = uint128(((uint256(deltaTimestamp)) * 1e18) / yearlySeconds);

        uint256 remainingCredit = depositEthAndTakeMaxCredit(amountEthToDeposit);

        //Set interest rate
        stdstore.target(address(pool)).sig(pool.interestRate.selector).checked_write(base - 1e18);

        vm.warp(block.timestamp + deltaTimestamp);

        uint128 unRealisedDebt = uint128((remainingCredit * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18);

        uint256 usedMarginExpected = remainingCredit + unRealisedDebt;

        uint256 usedMarginActual = vault_.getUsedMargin();

        assertEq(usedMarginActual, usedMarginExpected);
    }

    function testSuccess_syncInterests_GetOpenDebtUnchecked(uint32 blocksToRoll, uint128 baseAmountEthToDeposit)
        public
    {
        vm.assume(blocksToRoll <= 255_555_555); //up to the year 2122
        vm.assume(baseAmountEthToDeposit > 0);
        vm.assume(baseAmountEthToDeposit < 10);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint128 amountEthToDeposit = uint128(
            (
                ((10 * 10 ** 9 * 10 ** 18) / rateEthToUsd / 10 ** 18)
                    * 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals) * collFactor_
            ) / 100
        ); //equivalent to 10bn USD debt // This is always zero
        amountEthToDeposit += baseAmountEthToDeposit;
        uint256 remainingCredit = depositEthAndTakeMaxCredit(amountEthToDeposit); //10bn USD debt
        uint256 _lastBlock = block.number;

        uint64 _yearlyInterestRate = uint64(pool.interestRate());

        vm.roll(block.number + blocksToRoll);

        uint256 base;
        uint256 exponent;

        //gas: can't overflow as long as interest remains < 3.4*10**20 %/yr
        //gas: can't overflow: 1e18 + uint64 <<< uint128
        base = 1e18 + _yearlyInterestRate;

        //gas: only overflows when blocks.number > ~10**20
        exponent = ((block.number - uint32(_lastBlock)) * 1e18) / pool.YEARLY_SECONDS();

        uint256 usedMarginExpected = (remainingCredit * LogExpMath.pow(base, exponent)) / 1e18;

        uint256 usedMarginActual = vault_.getUsedMargin();

        assertEq(usedMarginExpected, usedMarginActual);
    }
}
