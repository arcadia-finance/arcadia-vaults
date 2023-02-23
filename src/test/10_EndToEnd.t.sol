/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import { LendingPool, DebtToken, ERC20, DataTypes } from "../../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../../lib/arcadia-lending/src/Tranche.sol";
import { ActionMultiCall } from "../actions/MultiCall.sol";
import { MultiActionMock } from "../mockups/MultiActionMock.sol";

abstract contract EndToEndTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    bytes3 public emptyBytes3;

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory), address(liquidator));
        pool.setVaultVersion(1, true);
        DataTypes.InterestRateConfiguration memory config = DataTypes.InterestRateConfiguration({
            baseRatePerYear: Constants.interestRate,
            highSlopePerYear: Constants.interestRate,
            lowSlopePerYear: Constants.interestRate,
            utilisationThreshold: Constants.utilisationThreshold
        });
        pool.setInterestConfig(config);

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

        vm.startPrank(vaultOwner);
        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(pool), type(uint256).max);
        dai.approve(address(proxy), type(uint256).max);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
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
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }
}

contract BorrowAndRepay is EndToEndTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
    }

    function testSuccess_getFreeMargin_AmountOfAllowedCredit(uint128 amountEth) public {
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 expectedValue = (((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) * collFactor_) / 100
            / 10 ** (18 - Constants.daiDecimals);
        uint256 actualValue = proxy.getFreeMargin();

        assertEq(actualValue, expectedValue);
    }

    function testSuccess_borrow_AllowCreditAfterDeposit(uint128 amountEth, uint128 amountCredit) public {
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth > 0);
        vm.assume(uint256(amountCredit) * collFactor_ < type(uint128).max); //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();

        assertEq(dai.balanceOf(vaultOwner), amountCredit);
    }

    function testRevert_borrow_NotAllowTooMuchCreditAfterDeposit(uint128 amountEth, uint128 amountCredit) public {
        vm.assume(amountEth > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(uint256(amountCredit) * collFactor_ < type(uint128).max); //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit > maxCredit);

        vm.startPrank(vaultOwner);
        vm.expectRevert("LP_B: Reverted");
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();

        assertEq(dai.balanceOf(vaultOwner), 0);
    }

    function testSuccess_borrow_IncreaseOfDebtPerBlock(uint128 amountEth, uint128 amountCredit, uint24 deltaTimestamp)
        public
    {
        vm.assume(amountEth > 0);
        uint256 _yearlyInterestRate = pool.interestRate();
        uint128 base = 1e18 + 5e16; //1 + r expressed as 18 decimals fixed point number
        uint128 exponent = (uint128(deltaTimestamp) * 1e18) / uint128(pool.YEARLY_SECONDS());
        vm.assume(amountCredit < type(uint128).max / LogExpMath.pow(base, exponent));

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;

        depositERC20InVault(eth, amountEth, vaultOwner);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals / 10 ** (18 - Constants.daiDecimals))
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();

        _yearlyInterestRate = pool.interestRate();
        base = 1e18 + uint128(_yearlyInterestRate);

        uint256 debtAtStart = proxy.getUsedMargin();

        vm.warp(block.timestamp + deltaTimestamp);

        uint256 actualDebt = proxy.getUsedMargin();

        uint128 expectedDebt = uint128(
            (
                debtAtStart
                    * (
                        LogExpMath.pow(
                            _yearlyInterestRate + 10 ** 18, (uint256(deltaTimestamp) * 10 ** 18) / pool.YEARLY_SECONDS()
                        )
                    )
            ) / 10 ** 18
        );

        assertEq(actualDebt, expectedDebt);
    }

    function testRevert_borrow_NotAllowCreditAfterLargeUnrealizedDebt(uint128 amountEth) public {
        uint128 valueOfOneEth = uint128((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint128 amountCredit = uint128(
            (
                ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                    * collFactor_
            ) / 100
        );
        vm.assume(amountCredit > 0);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();

        vm.roll(block.number + 10);
        vm.startPrank(vaultOwner);
        vm.expectRevert("LP_B: Reverted");
        pool.borrow(1, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();
    }

    function testSuccess_borrow_AllowAdditionalCreditAfterPriceIncrease(
        uint128 amountEth,
        uint128 amountCredit,
        uint16 newPrice
    ) public {
        vm.assume(amountEth > 0);
        vm.assume(newPrice * 10 ** Constants.oracleEthToUsdDecimals > rateEthToUsd);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_); //prevent overflow in takecredit with absurd values
        uint256 valueOfOneEth = uint128((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.startPrank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);
        vm.stopPrank();

        vm.prank(oracleOwner);
        uint256 newRateEthToUsd = newPrice * 10 ** Constants.oracleEthToUsdDecimals;
        oracleEthToUsd.transmit(int256(newRateEthToUsd));

        uint256 newValueOfOneEth = (Constants.WAD * newRateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        uint256 expectedAvailableCredit = (
            ((newValueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100 - amountCredit;

        uint256 actualAvailableCredit = proxy.getFreeMargin();

        assertEq(actualAvailableCredit, expectedAvailableCredit); //no blocks pass in foundry
    }

    function testRevert_withdraw_OpenDebtIsTooLarge(uint128 amountEth, uint128 amountEthWithdrawal) public {
        vm.assume(amountEth > 0 && amountEthWithdrawal > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);
        vm.assume(amountEth >= amountEthWithdrawal);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin() - 1);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        assetAmounts[0] = amountEthWithdrawal;
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_W: coll. value too low!");
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testSuccess_withdraw_OpenDebtIsNotTooLarge(
        uint128 amountEth,
        uint128 amountEthWithdrawal,
        uint128 amountCredit
    ) public {
        vm.assume(amountEth > 0 && amountEthWithdrawal > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);
        vm.assume(amountEth >= amountEthWithdrawal);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        vm.assume(
            proxy.getFreeMargin()
                > ((amountEthWithdrawal * valueOfOneEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                    + amountCredit
        );

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        assetAmounts[0] = amountEthWithdrawal;
        vm.startPrank(vaultOwner);
        proxy.getFreeMargin();
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testSuccess_syncInterests_IncreaseBalanceDebtContract(
        uint128 amountEth,
        uint128 amountCredit,
        uint24 deltaTimestamp
    ) public {
        vm.assume(amountEth > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        uint256 _yearlyInterestRate = pool.interestRate();

        uint256 balanceBefore = debt.totalAssets();

        vm.warp(block.timestamp + deltaTimestamp);
        uint256 balanceAfter = debt.totalAssets();

        uint128 base = uint128(_yearlyInterestRate) + 10 ** 18;
        uint128 exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.YEARLY_SECONDS());
        uint128 expectedDebt = uint128((amountCredit * (LogExpMath.pow(base, exponent))) / 10 ** 18);
        uint128 unrealisedDebt = expectedDebt - amountCredit;

        assertEq(unrealisedDebt, balanceAfter - balanceBefore);
    }

    function testSuccess_repay_ExactDebt(uint128 amountEth, uint128 amountCredit, uint16 blocksToRoll) public {
        vm.assume(amountEth > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.roll(block.number + blocksToRoll);

        uint256 openDebt = proxy.getUsedMargin();

        vm.prank(liquidityProvider);
        dai.transfer(vaultOwner, openDebt - amountCredit);

        vm.prank(vaultOwner);
        pool.repay(openDebt, address(proxy));

        assertEq(proxy.getUsedMargin(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxy.getUsedMargin(), 0);
    }

    function testSuccess_repay_ExessiveDebt(uint128 amountEth, uint128 amountCredit, uint16 blocksToRoll, uint8 factor)
        public
    {
        vm.assume(amountEth > 0);
        vm.assume(factor > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(liquidityProvider);
        dai.transfer(vaultOwner, factor * amountCredit);

        vm.roll(block.number + blocksToRoll);

        uint256 openDebt = proxy.getUsedMargin();
        uint256 balanceBefore = dai.balanceOf(vaultOwner);

        vm.startPrank(vaultOwner);
        pool.repay(openDebt * factor, address(proxy));
        vm.stopPrank();

        uint256 balanceAfter = dai.balanceOf(vaultOwner);

        assertEq(balanceBefore - openDebt, balanceAfter);
        assertEq(proxy.getUsedMargin(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxy.getUsedMargin(), 0);
    }

    function testSuccess_repay_PartialDebt(
        uint128 amountEth,
        uint128 amountCredit,
        uint24 deltaTimestamp,
        uint128 toRepay
    ) public {
        vm.assume(amountEth > 0);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        vm.assume(amountEth < type(uint128).max / collFactor_);

        uint256 valueOfOneEth = (Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals;
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        uint256 maxCredit = (
            ((valueOfOneEth * amountEth) / 10 ** Constants.ethDecimals) / 10 ** (18 - Constants.daiDecimals)
                * collFactor_
        ) / 100;
        vm.assume(amountCredit <= maxCredit);

        depositERC20InVault(eth, amountEth, vaultOwner);

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        uint256 _yearlyInterestRate = pool.interestRate();

        vm.warp(block.timestamp + deltaTimestamp);

        vm.assume(toRepay < amountCredit);

        vm.prank(vaultOwner);
        pool.repay(toRepay, address(proxy));
        uint128 base = uint128(_yearlyInterestRate) + 10 ** 18;
        uint128 exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.YEARLY_SECONDS());
        uint128 expectedDebt = uint128((amountCredit * (LogExpMath.pow(base, exponent))) / 10 ** 18) - toRepay;

        assertEq(proxy.getUsedMargin(), expectedDebt);

        vm.warp(block.timestamp + deltaTimestamp);
        _yearlyInterestRate = pool.interestRate();
        base = uint128(_yearlyInterestRate) + 10 ** 18;
        exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.YEARLY_SECONDS());
        expectedDebt = uint128((expectedDebt * (LogExpMath.pow(base, exponent))) / 10 ** 18);

        assertEq(proxy.getUsedMargin(), expectedDebt);
    }
}

contract DoActionWithLeverage is EndToEndTest {
    using stdStorage for StdStorage;

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
        multiActionMock = new MultiActionMock();
        action = new ActionMultiCall(address(mainRegistry));
        mainRegistry.setAllowedAction(address(action), true);
        vm.stopPrank();

        vm.prank(vaultOwner);
        proxy.setAssetManager(address(pool), true);
    }

    function testSuccess_doActionWithLeverage_repayExact(uint32 daiDebt, uint72 daiCollateral, uint32 ethOut) public {
        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0); //18 decimals
        (uint256 daiRate,) = oracleHub.getRate(oracleDaiToUsdArr, 0); //18 decimals

        uint256 daiIn = uint256(ethOut) * ethRate / 10 ** Constants.ethDecimals * 10 ** Constants.daiDecimals / daiRate;

        //With leverage -> daiIn should be bigger than the available collateral
        vm.assume(daiIn > daiCollateral);

        uint256 daiMargin = daiIn - daiCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(daiMargin + daiDebt <= collateralFactor * daiIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxy)).checked_write(daiDebt);

        //Deposit daiCollateral in Vault (have to burn first to avoid overflow)
        vm.prank(liquidityProvider);
        dai.burn(type(uint64).max);
        depositERC20InVault(dai, daiCollateral, vaultOwner);

        //Prepare input parameters
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), daiIn);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)", address(dai), address(eth), daiIn, uint256(ethOut)
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxy), uint256(ethOut));

        vm.prank(tokenCreatorAddress);
        eth.mint(address(multiActionMock), ethOut);

        to[0] = address(dai);
        to[1] = address(multiActionMock);
        to[2] = address(eth);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(dai);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = daiCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(eth);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        //Do swap on leverage
        vm.prank(vaultOwner);
        pool.doActionWithLeverage(daiMargin, address(proxy), address(action), callData, emptyBytes3);

        assertEq(dai.balanceOf(address(pool)), type(uint128).max - daiMargin);
        assertEq(dai.balanceOf(address(multiActionMock)), daiIn);
        assertEq(eth.balanceOf(address(proxy)), ethOut);
        assertEq(debt.balanceOf(address(proxy)), uint256(daiDebt) + daiMargin);

        uint256 debtAmount = proxy.getUsedMargin();

        bytes[] memory dataArr = new bytes[](2);
        dataArr[0] = abi.encodeWithSignature("approve(address,uint256)", address(pool), type(uint256).max);
        dataArr[1] = abi.encodeWithSignature("executeRepay(address,address,address,uint256)", address(pool), address(dai), address(proxy), 0);

        address[] memory tos = new address[](2);
        tos[0] = address(dai);
        tos[1] = address(action);

        ActionData memory ad;

        vm.startPrank(liquidityProvider);
        dai.transfer(address(action), debtAmount);
        action.executeAction(abi.encode(ad, ad, tos, dataArr));
        vm.stopPrank();

        assertEq(debt.balanceOf(address(proxy)), 0);
        assertEq(proxy.getUsedMargin(), 0);
    }

    function testSuccess_doActionWithLeverage(uint32 daiDebt, uint72 daiCollateral, uint32 ethOut) public {
        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0); //18 decimals
        (uint256 daiRate,) = oracleHub.getRate(oracleDaiToUsdArr, 0); //18 decimals

        uint256 daiIn = uint256(ethOut) * ethRate / 10 ** Constants.ethDecimals * 10 ** Constants.daiDecimals / daiRate;

        //With leverage -> daiIn should be bigger than the available collateral
        vm.assume(daiIn > daiCollateral);

        uint256 daiMargin = daiIn - daiCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(daiMargin + daiDebt <= collateralFactor * daiIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxy)).checked_write(daiDebt);

        //Deposit daiCollateral in Vault (have to burn first to avoid overflow)
        vm.prank(liquidityProvider);
        dai.burn(type(uint64).max);
        depositERC20InVault(dai, daiCollateral, vaultOwner);

        //Prepare input parameters
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), daiIn);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)", address(dai), address(eth), daiIn, uint256(ethOut)
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxy), uint256(ethOut));

        vm.prank(tokenCreatorAddress);
        eth.mint(address(multiActionMock), ethOut);

        to[0] = address(dai);
        to[1] = address(multiActionMock);
        to[2] = address(eth);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(dai);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = daiCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(eth);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        //Do swap on leverage
        vm.prank(vaultOwner);
        pool.doActionWithLeverage(daiMargin, address(proxy), address(action), callData, emptyBytes3);

        assertEq(dai.balanceOf(address(pool)), type(uint128).max - daiMargin);
        assertEq(dai.balanceOf(address(multiActionMock)), daiIn);
        assertEq(eth.balanceOf(address(proxy)), ethOut);
        assertEq(debt.balanceOf(address(proxy)), uint256(daiDebt) + daiMargin);
    }

    function testRevert_doActionWithLeverage_InsufficientCollateral(uint64 daiDebt, uint64 daiCollateral, uint64 ethOut)
        public
    {
        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0); //18 decimals
        (uint256 daiRate,) = oracleHub.getRate(oracleDaiToUsdArr, 0); //18 decimals

        uint256 daiIn = uint256(ethOut) * ethRate / 10 ** Constants.ethDecimals * 10 ** Constants.daiDecimals / daiRate;

        //With leverage -> daiIn should be bigger than the available collateral
        vm.assume(daiIn > daiCollateral);

        uint256 daiMargin = daiIn - daiCollateral;

        //Action is not successfull -> total debt after transaction should be bigger than the Collateral Value
        vm.assume(daiMargin + daiDebt > collateralFactor * daiIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(daiDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxy)).checked_write(daiDebt);

        //Deposit daiCollateral in Vault (have to burn first to avoid overflow)
        vm.prank(liquidityProvider);
        dai.burn(type(uint64).max);
        depositERC20InVault(dai, daiCollateral, vaultOwner);

        //Prepare input parameters
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), daiIn);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)", address(dai), address(eth), daiIn, uint256(ethOut)
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxy), uint256(ethOut));

        vm.prank(tokenCreatorAddress);
        eth.mint(address(multiActionMock), ethOut);

        to[0] = address(dai);
        to[1] = address(multiActionMock);
        to[2] = address(eth);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(dai);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = daiCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(eth);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        //Do swap on leverage
        vm.startPrank(vaultOwner);
        vm.expectRevert("V_VMA: coll. value too low");
        pool.doActionWithLeverage(daiMargin, address(proxy), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }
}
