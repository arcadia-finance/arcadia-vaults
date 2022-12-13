/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import {LendingPool, DebtToken, ERC20} from "../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../lib/arcadia-lending/src/Tranche.sol";

contract VaultTestExtension is Vault {
    //Function necessary to set the liquidation threshold, since cheatcodes do not work
    // with packed structs
    function setLiquidationThreshold(uint16 liqThres) public {
        vault.liqThres = liqThres;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }
}

contract vaultTests is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    VaultTestExtension public vault_;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    uint16[] public collateralFactors = new uint16[](3);
    uint16[] public liquidationThresholds = new uint16[](3);

    struct Assets {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
        uint256[] assetTypes;
    }

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(
            address(factory),
            address(mainRegistry)
        );

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));

        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
    }

    //this is a before each
    function setUp() public {
        vm.prank(vaultOwner);
        vault_ = new VaultTestExtension();

        vm.startPrank(creatorAddress);
        factory.setNewVaultInfo(address(mainRegistry), address(vault_), Constants.upgradeProof1To2);
        factory.confirmNewVaultInfo();
        vm.stopPrank();

        uint256 slot = stdstore.target(address(factory)).sig(factory.isVault.selector).with_key(address(vault_)).find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factory), loc, mockedCurrentTokenId);

        vm.startPrank(vaultOwner);
        vault_.initialize(vaultOwner, address(mainRegistry), 1);

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

        collateralFactors[0] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[1] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        collateralFactors[2] = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        liquidationThresholds[0] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[1] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        liquidationThresholds[2] = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
    }

    /* ///////////////////////////////////////////////////////////////
                        VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_initialize_AlreadyInitialized() public {
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_I: Already initialized!");
        vault_.initialize(vaultOwner, address(mainRegistry), 1);
        vm.stopPrank();
    }

    function testSuccess_upgradeVault(address newImplementation, uint16 newVersion) public {
        vm.startPrank(address(factory));
        vault_.upgradeVault(newImplementation, newVersion);
        vm.stopPrank();

        uint16 expectedVersion = vault_.vaultVersion();

        assertEq(expectedVersion, newVersion);
    }

    function testRevert_upgradeVault_byNonOwner(address newImplementation, uint16 newVersion, address nonOwner)
        public
    {
        vm.assume(nonOwner != address(factory));

        vm.startPrank(nonOwner);
        vm.expectRevert("VL: You are not the factory");
        vault_.upgradeVault(newImplementation, newVersion);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                    OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_transferOwnership_NonOwner(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(vaultOwner, vault_.owner());

        vm.startPrank(sender);
        vm.expectRevert("VL: You are not the factory");
        vault_.transferOwnership(to);
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

    /* ///////////////////////////////////////////////////////////////
                    BASE CURRENCY LOGIC
    /////////////////////////////////////////////////////////////// */

    function testSuccess_setBaseCurrency(address authorised) public {
        uint256 slot = stdstore.target(address(vault_)).sig(vault_.allowed.selector).with_key(authorised).find();
        bytes32 loc = bytes32(slot);
        bool allowed = true;
        bytes32 value = bytes32(abi.encode(allowed));
        vm.store(address(vault_), loc, value);

        vm.startPrank(authorised);
        vault_.setBaseCurrency(address(eth));
        vm.stopPrank();

        (, address baseCurrency) = vault_.vault();
        assertEq(baseCurrency, address(eth));
    }

    function testRevert_setBaseCurrency_NonAuthorized(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != vaultOwner);
        vm.assume(unprivilegedAddress_ != address(pool));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("VL: You are not authorized");
        vault_.setBaseCurrency(address(eth));
        vm.stopPrank();

        (, address baseCurrency) = vault_.vault();
        assertEq(baseCurrency, address(dai));
    }

    function testRevert_setBaseCurrency_WithDebt(address authorised) public {
        uint256 slot = stdstore.target(address(vault_)).sig(vault_.allowed.selector).with_key(authorised).find();
        bytes32 loc = bytes32(slot);
        bool allowed = true;
        bytes32 value = bytes32(abi.encode(allowed));
        vm.store(address(vault_), loc, value);

        slot = stdstore.target(address(debt)).sig(debt.totalSupply.selector).find();
        loc = bytes32(slot);
        bytes32 addDebt = bytes32(abi.encode(1));
        vm.store(address(debt), loc, addDebt);

        slot = stdstore.target(address(debt)).sig(debt.realisedDebt.selector).find();
        loc = bytes32(slot);
        vm.store(address(debt), loc, addDebt);

        slot = stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).find();
        loc = bytes32(slot);
        vm.store(address(debt), loc, addDebt);

        vm.startPrank(authorised);
        vm.expectRevert("VL_SBC: Can't change baseCurrency when Used Margin > 0");
        vault_.setBaseCurrency(address(eth));
        vm.stopPrank();

        (, address baseCurrency) = vault_.vault();
        assertEq(baseCurrency, address(dai));
    }

    /* ///////////////////////////////////////////////////////////////
                MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    function testRevert_openTrustedMarginAccount_AlreadySet(address trustedProtocol) public {
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_OMA: ALREADY SET");
        vault_.openTrustedMarginAccount(trustedProtocol);
        vm.stopPrank();
    }

    function testRevert_openTrustedMarginAccount_NonOwner(address nonOwner, address trustedProtocol) public {
        vm.assume(nonOwner != vaultOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("VL: You are not the owner");
        vault_.openTrustedMarginAccount(trustedProtocol);
        vm.stopPrank();
    }

    function testSuccess_closeTrustedMarginAccount_CloseNonSetTrustedMarginAccount() public {
        vm.startPrank(vaultOwner);
        vault_.closeTrustedMarginAccount();

        assertEq(vault_.isTrustedProtocolSet(), false);
    }

    function testRevert_closeTrustedMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != vaultOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("VL: You are not the owner");
        vault_.closeTrustedMarginAccount();
    }

    /* ///////////////////////////////////////////////////////////////
                        MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    //ToDo: increaseMarginPosition, decreaseMarginPosition, getCollateralValue

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
        assertLt(gasStart - gasAfter, 200000);
    }

    function testSuccess_getUsedMargin_ZeroInitially() public {
        uint256 openDebt = vault_.getUsedMargin();
        assertEq(openDebt, 0);
    }

    function testSuccess_getFreeMargin_ZeroInitially() public {
        uint256 remainingCredit = vault_.getFreeMargin();
        assertEq(remainingCredit, 0);
    }

    function testSuccess_getFreeMargin_AfterFirstDeposit(uint8 amount) public {
        depositEthInVault(amount, vaultOwner);

        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amount
            / 10 ** (18 - Constants.daiDecimals);
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        uint256 expectedRemaining = (depositValue * collFactor) / 100;
        assertEq(expectedRemaining, vault_.getFreeMargin());
    }

    function testSuccess_getFreeMargin_AfterTopUp(uint8 amountEth, uint8 amountLink, uint128[] calldata tokenIds)
        public
    {
        vm.assume(tokenIds.length < 10 && tokenIds.length > 1);
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        depositEthInVault(amountEth, vaultOwner);
        uint256 depositValueEth = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth;
        assertEq((depositValueEth / 10 ** (18 - Constants.daiDecimals) * collFactor) / 100, vault_.getFreeMargin());

        depositLinkInVault(amountLink, vaultOwner);
        uint256 depositValueLink =
            ((Constants.WAD * rateLinkToUsd) / 10 ** Constants.oracleLinkToUsdDecimals) * amountLink;
        assertEq(
            ((depositValueEth + depositValueLink) / 10 ** (18 - Constants.daiDecimals) * collFactor) / 100,
            vault_.getFreeMargin()
        );

        (, uint256[] memory assetIds,,) = depositBaycInVault(tokenIds, vaultOwner);
        uint256 depositBaycValue = (
            (Constants.WAD * rateWbaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleEthToUsdDecimals + Constants.oracleWbaycToEthDecimals)
        ) * assetIds.length;
        assertEq(
            ((depositValueEth + depositValueLink + depositBaycValue) / 10 ** (18 - Constants.daiDecimals) * collFactor)
                / 100,
            vault_.getFreeMargin()
        );
    }

    function testSuccess_getFreeMargin_AfterTakingCredit(uint8 amountEth, uint128 amountCredit) public {
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
            / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        vm.assume((depositValue * collFactor) / 100 > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner);

        uint256 actualRemainingCredit = vault_.getFreeMargin();
        uint256 expectedRemainingCredit = (depositValue * collFactor) / 100 - amountCredit;

        assertEq(expectedRemainingCredit, actualRemainingCredit);
    }

    function testSuccess_getFreeMargin_NoOverflows(uint128 amountEth, uint8 factor) public {
        vm.assume(amountEth < 10 * 10 ** 9 * 10 ** 18);
        vm.assume(amountEth > 0);

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );

        depositERC20InVault(eth, amountEth, vaultOwner);
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        vm.prank(vaultOwner);
        pool.borrow((((amountEth * collFactor) / 100) * factor) / 255, address(vault_), vaultOwner);

        uint256 currentValue = vault_.getVaultValue(address(dai));
        uint256 openDebt = vault_.getUsedMargin();

        uint256 maxAllowedCreditLocal;
        uint256 remainingCreditLocal;
        //gas: cannot overflow unless currentValue is more than
        // 1.15**57 *10**18 decimals, which is too many billions to write out
        maxAllowedCreditLocal = (currentValue * collFactor) / 100;

        //gas: explicit check is done to prevent underflow
        remainingCreditLocal = maxAllowedCreditLocal > openDebt ? maxAllowedCreditLocal - openDebt : 0;

        uint256 remainingCreditFetched = vault_.getFreeMargin();

        //remainingCreditFetched has a lot of unchecked operations
        //-> we check that the checked operations never reverts and is
        //always equal to the unchecked operations
        assertEq(remainingCreditLocal, remainingCreditFetched);
    }

    /* ///////////////////////////////////////////////////////////////
                        LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testSuccess_liquidate_NewOwnerIsLiquidator(address liquidationKeeper) public {
        vm.assume(
            liquidationKeeper != address(this) && liquidationKeeper != address(0)
                && liquidationKeeper != address(factory)
        );

        uint256 slot = stdstore.target(address(debt)).sig(debt.totalSupply.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 addDebt = bytes32(abi.encode(100000000));
        vm.store(address(debt), loc, addDebt);

        slot = stdstore.target(address(debt)).sig(debt.realisedDebt.selector).find();
        loc = bytes32(slot);
        vm.store(address(debt), loc, addDebt);

        slot = stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(vault_)).find();
        loc = bytes32(slot);
        vm.store(address(debt), loc, addDebt);

        //Set liquidation treshhold on the vault_
        vault_.setLiquidationThreshold(mainRegistry.DEFAULT_COLLATERAL_FACTOR());

        vm.startPrank(liquidationKeeper);
        factory.liquidate(address(vault_));
        vm.stopPrank();

        assertEq(vault_.owner(), address(liquidator));
    }

    function testRevert_liquidateVault_NonFactory(address liquidationKeeper) public {
        vm.assume(liquidationKeeper != address(factory));

        assertEq(vault_.owner(), vaultOwner);

        vm.expectRevert("VL: You are not the factory");
        vault_.liquidateVault(liquidationKeeper);

        assertEq(vault_.owner(), vaultOwner);
    }

    /* ///////////////////////////////////////////////////////////////
                ASSET DEPOSIT/WITHDRAWN LOGIC
    /////////////////////////////////////////////////////////////// */

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_deposit_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen, uint8 typesLen)
        public
    {
        vm.startPrank(vaultOwner);
        assertEq(vault_.owner(), vaultOwner);

        vm.assume((addrLen != idLen && addrLen != amountLen && addrLen != typesLen));

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; i++) {
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

        uint256[] memory assetTypes = new uint256[](typesLen);
        for (uint256 l; l < typesLen; l++) {
            assetTypes[l] = l;
        }

        vm.expectRevert("Length mismatch");
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testRevert_deposit_ERC20IsNotWhitelisted(address inputAddr) public {
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));

        vm.startPrank(vaultOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.expectRevert("Not all assets are whitelisted!");
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testRevert_deposit_ERC721IsNotWhitelisted(address inputAddr, uint256 id) public {
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));

        vm.startPrank(vaultOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.expectRevert("Not all assets are whitelisted!");
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        console.log("test");
        emit log("test");
    }

    function testSuccess_deposit_SingleERC20(uint16 amount) public {
        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault_.erc20Stored(0), address(eth));
    }

    function testSuccess_deposit_MultipleSameERC20(uint16 amount) public {
        vm.assume(amount <= 50000);

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        (uint256 erc20StoredDuring,,,) = vault_.getLengths();

        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        (uint256 erc20StoredAfter,,,) = vault_.getLengths();

        assertEq(erc20StoredDuring, erc20StoredAfter);
    }

    function testSuccess_deposit_SingleERC721() public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault_.erc721Stored(0), address(bayc));
    }

    function testSuccess_deposit_MultipleERC721() public {
        vm.prank(creatorAddress);
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault_.erc721Stored(0), address(bayc));
        (, uint256 erc721LengthFirst,,) = vault_.getLengths();
        assertEq(erc721LengthFirst, 1);

        assetIds[0] = 3;
        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault_.erc721Stored(1), address(bayc));
        (, uint256 erc721LengthSecond,,) = vault_.getLengths();
        assertEq(erc721LengthSecond, 2);

        assertEq(vault_.erc721TokenIds(0), 1);
        assertEq(vault_.erc721TokenIds(1), 3);
    }

    function testSuccess_deposit_SingleERC1155() public {
        vm.prank(creatorAddress);
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 2;

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(vault_.erc1155Stored(0), address(interleave));
        assertEq(vault_.erc1155TokenIds(0), 1);
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

        uint256[] memory assetTypes = new uint256[](3);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 1;

        vm.startPrank(creatorAddress);
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
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

        uint256[] memory assetTypes = new uint256[](4);
        assetTypes[0] = 0;
        assetTypes[1] = 0;
        assetTypes[2] = 1;
        assetTypes[3] = 2;

        vm.startPrank(creatorAddress);
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: 9999,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testRevert_deposit_ByNonOwner(address sender) public {
        vm.assume(sender != vaultOwner);

        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10 ** Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vm.expectRevert("VL: You are not the owner");
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testSuccess_withdraw_ERC20NoDebt(uint8 baseAmountDeposit) public {
        uint256 valueAmount = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);

        uint256 vaultValue = vault_.getVaultValue(address(dai));

        assertEq(vaultValue, valueAmount);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(vault_), vaultOwner, assetInfo.assetAmounts[0]);
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts, assetInfo.assetTypes);

        uint256 vaultValueAfter = vault_.getVaultValue(address(dai));
        assertEq(vaultValueAfter, 0);
        vm.stopPrank();
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

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        vm.assume(amountCredit < ((valueDeposit - valueWithdraw) * collFactor) / 100);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);
        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner);
        assetInfo.assetAmounts[0] = amountWithdraw;
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts, assetInfo.assetTypes);
        vm.stopPrank();

        uint256 actualValue = vault_.getVaultValue(address(dai));
        uint256 expectedValue = valueDeposit - valueWithdraw;

        assertEq(expectedValue, actualValue);
    }

    function testRevert_withdraw_ERC20AfterTakingCredit(
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

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        vm.assume(amountCredit <= (valueDeposit * collFactor) / 100);
        vm.assume(amountCredit > ((valueDeposit - ValueWithdraw) * collFactor) / 100);

        Assets memory assetInfo = depositEthInVault(baseAmountDeposit, vaultOwner);
        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner);
        assetInfo.assetAmounts[0] = amountWithdraw;
        vm.expectRevert("V_W: coll. value too low!");
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts, assetInfo.assetTypes);
        vm.stopPrank();
    }

    function testSuccess_withdraw_ERC721AfterTakingCredit(uint128[] calldata tokenIdsDeposit, uint8 baseAmountCredit)
        public
    {
        vm.assume(tokenIdsDeposit.length < 50); //test speed
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        (, uint256[] memory assetIds,,) = depositBaycInVault(tokenIdsDeposit, vaultOwner);

        uint256 randomAmounts = assetIds.length > 0
            ? uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "testWithrawERC721AfterTakingCredit(uint256[],uint8)", assetIds, baseAmountCredit
                    )
                )
            ) % assetIds.length
            : 0;

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        uint256 rateInUsd = (
            ((Constants.WAD * rateWbaycToEth) / 10 ** Constants.oracleWbaycToEthDecimals) * rateEthToUsd
        ) / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);
        uint256 valueOfDeposit = rateInUsd * assetIds.length;

        uint256 valueOfWithdrawal = rateInUsd * randomAmounts;

        vm.assume((valueOfDeposit * collFactor) / 100 >= amountCredit);
        vm.assume(valueOfWithdrawal < valueOfDeposit);
        vm.assume(amountCredit < ((valueOfDeposit - valueOfWithdrawal) * collFactor) / 100);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner);

        uint256[] memory withdrawalIds = new uint256[](randomAmounts);
        address[] memory withdrawalAddresses = new address[](randomAmounts);
        uint256[] memory withdrawalAmounts = new uint256[](randomAmounts);
        uint256[] memory withdrawalTypes = new uint256[](randomAmounts);
        for (uint256 i; i < randomAmounts; i++) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
            withdrawalTypes[i] = 1;
        }

        vault_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts, withdrawalTypes);

        uint256 actualValue = vault_.getVaultValue(address(dai));
        uint256 expectedValue = valueOfDeposit - valueOfWithdrawal;

        assertEq(expectedValue, actualValue);
    }

    function testRevert_withdraw_ERC721(uint128[] calldata tokenIdsDeposit, uint8 amountsWithdrawn) public {
        vm.assume(tokenIdsDeposit.length < 50); //test speed

        (, uint256[] memory assetIds,,) = depositBaycInVault(tokenIdsDeposit, vaultOwner);
        vm.assume(assetIds.length >= amountsWithdrawn && assetIds.length > 1 && amountsWithdrawn > 1);

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint256 rateInUsd = (
            ((Constants.WAD * rateWbaycToEth) / 10 ** Constants.oracleWbaycToEthDecimals) * rateEthToUsd
        ) / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);

        uint128 maxAmountCredit = uint128(((assetIds.length - amountsWithdrawn) * rateInUsd * collFactor) / 100);

        vm.startPrank(vaultOwner);
        pool.borrow(maxAmountCredit + 1, address(vault_), vaultOwner);

        uint256[] memory withdrawalIds = new uint256[](amountsWithdrawn);
        address[] memory withdrawalAddresses = new address[](amountsWithdrawn);
        uint256[] memory withdrawalAmounts = new uint256[](amountsWithdrawn);
        uint256[] memory withdrawalTypes = new uint256[](amountsWithdrawn);
        for (uint256 i; i < amountsWithdrawn; i++) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
            withdrawalTypes[i] = 1;
        }

        vm.expectRevert("V_W: coll. value too low!");
        vault_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts, withdrawalTypes);
    }

    function testRevert_withdraw_ByNonOwner(uint8 depositAmount, uint8 withdrawalAmount, address sender) public {
        vm.assume(sender != vaultOwner);
        vm.assume(depositAmount > withdrawalAmount);
        Assets memory assetInfo = depositEthInVault(depositAmount, vaultOwner);

        assetInfo.assetAmounts[0] = withdrawalAmount * 10 ** Constants.ethDecimals;
        vm.startPrank(sender);
        vm.expectRevert("VL: You are not the owner");
        vault_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts, assetInfo.assetTypes);
    }

    /* ///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function depositEthAndTakeMaxCredit(uint128 amountEth) public returns (uint256) {
        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );

        depositERC20InVault(eth, amountEth, vaultOwner);
        vm.startPrank(vaultOwner);
        uint256 remainingCredit = vault_.getFreeMargin();
        pool.borrow(uint128(remainingCredit), address(vault_), vaultOwner);
        vm.stopPrank();

        return remainingCredit;
    }

    function depositERC20InVault(ERC20Mock token, uint128 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositEthInVault(uint8 amount, address sender) public returns (Assets memory assetInfo) {
        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();

        assetInfo = Assets({
            assetAddresses: assetAddresses,
            assetIds: assetIds,
            assetAmounts: assetAmounts,
            assetTypes: assetTypes
        });
    }

    function depositLinkInVault(uint8 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        vm.prank(creatorAddress);
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            collateralFactors,
            liquidationThresholds
        );

        assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        assetTypes = new uint256[](1);
        assetTypes[0] = 0;

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositBaycInVault(uint128[] memory tokenIds, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        vm.prank(creatorAddress);
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );

        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIdToWorkWith = tokenIds[i];
            while (bayc.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            bayc.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(bayc);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        vault_.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                    DEPRECIATED TESTS
    /////////////////////////////////////////////////////////////// */
    //ToDo: All depreciated tests should be moved to Arcadia Lending, to double check that everything is covered there
    struct debtInfo {
        uint16 collFactor; //factor 100
        uint8 liqThres; //factor 100
        uint8 baseCurrency;
    }

    function testSuccess_borrow(uint8 baseAmountDeposit, uint8 baseAmountCredit) public {
        uint256 amountDeposit = baseAmountDeposit * 10 ** Constants.daiDecimals;
        vm.assume(amountDeposit > 0);
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();

        vm.assume((amountDeposit * collFactor) / 100 >= amountCredit);
        depositEthInVault(baseAmountDeposit, vaultOwner);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(vault_), vaultOwner);

        assertEq(dai.balanceOf(vaultOwner), amountCredit);
        assertEq(vault_.getUsedMargin(), amountCredit); //no blocks have passed
    }

    function testRevert_borrow_AsNonOwner(uint8 amountEth, uint128 amountCredit) public {
        vm.assume(amountCredit > 0);
        vm.assume(unprivilegedAddress != vaultOwner);
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth;
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        vm.assume((depositValue * collFactor) / 100 > amountCredit);
        depositEthInVault(amountEth, vaultOwner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountCredit, address(vault_), vaultOwner);
    }

    function testSuccess_MinCollValueUnchecked() public {
        //uint256 minCollValue;
        //unchecked {minCollValue = uint256(debt._usedMargin) * debt.collFactor / 100;}
        assertTrue(uint256(type(uint128).max) * type(uint16).max < type(uint256).max);
    }

    function testSuccess_CheckBaseUnchecked() public {
        uint256 base256 = uint128(1e18) + type(uint64).max + 1;
        uint128 base128 = uint128(uint128(1e18) + type(uint64).max + 1);

        //assert that 1e18 + uint64 < uint128 can't overflow
        assertTrue(base256 == base128);
    }

    //overflows from deltaBlocks = 894262060268226281981748468
    function testSuccess_CheckExponentUnchecked() public {
        uint256 yearlyBlocks = 2628000;
        uint256 maxDeltaBlocks = (uint256(type(uint128).max) * uint256(yearlyBlocks)) / 10 ** 18;

        uint256 exponent256 = (maxDeltaBlocks * 1e18) / yearlyBlocks;
        uint128 exponent128 = uint128((maxDeltaBlocks * uint256(1e18)) / yearlyBlocks);

        assertTrue(exponent256 == exponent128);

        uint256 exponent256Overflow = (((maxDeltaBlocks + 1) * 1e18) / yearlyBlocks);
        uint128 exponent128Overflow = uint128(((maxDeltaBlocks + 1) * 1e18) / yearlyBlocks);

        assertTrue(exponent256Overflow != exponent128Overflow);
        assertTrue(exponent128Overflow == exponent256Overflow - type(uint128).max - 1);
    }

    function testSuccess_CheckUnrealisedDebtUnchecked(uint64 base, uint24 deltaBlocks, uint128 openDebt) public {
        vm.assume(base <= 10 * 10 ** 18); //1000%
        vm.assume(base >= 10 ** 18);
        vm.assume(deltaBlocks <= 13140000); //5 year
        vm.assume(openDebt <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        uint256 yearlyBlocks = 2628000;
        uint128 exponent = uint128(((uint256(deltaBlocks)) * 1e18) / yearlyBlocks);
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
        uint24 deltaBlocks,
        uint128 openDebt,
        uint16 additionalDeposit
    ) public {
        vm.assume(base <= 10 * 10 ** 18); //1000%
        vm.assume(base >= 10 ** 18); //No negative interest rate possible
        vm.assume(deltaBlocks <= 13140000); //5 year
        vm.assume(additionalDeposit > 0);
        //        vm.assume(additionalDeposit < 10);
        vm.assume(openDebt <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint128 amountEthToDeposit = uint128(
            (
                (openDebt / rateEthToUsd / 10 ** 18) * 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals)
                    * collFactor
            ) / 100
        ); // This is always zero
        amountEthToDeposit += uint128(additionalDeposit);

        uint256 yearlyBlocks = 2628000;
        uint128 exponent = uint128(((uint256(deltaBlocks)) * 1e18) / yearlyBlocks);

        uint256 remainingCredit = depositEthAndTakeMaxCredit(amountEthToDeposit);

        //Set interest rate
        stdstore.target(address(pool)).sig(pool.interestRate.selector).checked_write(base - 1e18);

        vm.roll(block.number + deltaBlocks);

        uint128 unRealisedDebt = uint128((remainingCredit * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18);

        uint256 usedMarginExpected = remainingCredit + unRealisedDebt;

        uint256 usedMarginActual = vault_.getUsedMargin();

        assertEq(usedMarginActual, usedMarginExpected);
    }

    function testSuccess_syncInterests_GetOpenDebtUnchecked(uint32 blocksToRoll, uint128 baseAmountEthToDeposit)
        public
    {
        vm.assume(blocksToRoll <= 255555555); //up to the year 2122
        vm.assume(baseAmountEthToDeposit > 0);
        vm.assume(baseAmountEthToDeposit < 10);
        uint16 collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        uint128 amountEthToDeposit = uint128(
            (
                ((10 * 10 ** 9 * 10 ** 18) / rateEthToUsd / 10 ** 18)
                    * 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals) * collFactor
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
        exponent = ((block.number - uint32(_lastBlock)) * 1e18) / pool.YEARLY_BLOCKS();

        uint256 usedMarginExpected = (remainingCredit * LogExpMath.pow(base, exponent)) / 1e18;

        uint256 usedMarginActual = vault_.getUsedMargin();

        assertEq(usedMarginExpected, usedMarginActual);
    }
}
