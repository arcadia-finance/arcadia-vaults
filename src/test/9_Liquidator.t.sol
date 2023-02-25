/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import { LendingPool, DebtToken, ERC20 } from "../../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../../lib/arcadia-lending/src/Tranche.sol";

contract LiquidatorExtension is Liquidator {
    constructor(address factory_) Liquidator(factory_) { }

    function getAuctionInformationPartOne(address vault_)
        public
        view
        returns (uint128 openDebt, uint32 startTime, bool inAuction, uint80 maxInitiatorFee, address baseCurrency)
    {
        openDebt = auctionInformation[vault_].openDebt;
        startTime = auctionInformation[vault_].startTime;
        inAuction = auctionInformation[vault_].inAuction;
        maxInitiatorFee = auctionInformation[vault_].maxInitiatorFee;
        baseCurrency = auctionInformation[vault_].baseCurrency;
    }

    function getAuctionInformationPartTwo(address vault_)
        public
        view
        returns (
            uint16 startPriceMultiplier,
            uint8 minPriceMultiplier,
            uint8 initiatorRewardWeight,
            uint8 penaltyWeight,
            uint16 cutoffTime,
            address originalOwner,
            address trustedCreditor,
            uint64 base
        )
    {
        startPriceMultiplier = auctionInformation[vault_].startPriceMultiplier;
        minPriceMultiplier = auctionInformation[vault_].minPriceMultiplier;
        initiatorRewardWeight = auctionInformation[vault_].initiatorRewardWeight;
        penaltyWeight = auctionInformation[vault_].penaltyWeight;
        cutoffTime = auctionInformation[vault_].cutoffTime;
        originalOwner = auctionInformation[vault_].originalOwner;
        trustedCreditor = auctionInformation[vault_].trustedCreditor;
        base = auctionInformation[vault_].base;
    }
}

contract LiquidatorTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;
    LiquidatorExtension liquidator_;

    bytes3 public emptyBytes3;

    address private liquidationInitiator = address(8);
    address private auctionBuyer = address(9);

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator_ = new LiquidatorExtension(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory), address(liquidator_));
        pool.setVaultVersion(1, true);
        pool.setMaxInitiatorFee(type(uint80).max);
        liquidator_.setAuctionCurveParameters(3600, 14_400);
        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50, 0);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint64).max, liquidityProvider);
    }

    //this is a before each
    function setUp() public {
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

        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(proxy), type(uint256).max);

        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        dai.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.prank(auctionBuyer);
        dai.approve(address(liquidator_), type(uint256).max);
    }

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */
    function testSuccess_deployment() public {
        assertEq(liquidator_.factory(), address(factory));
        assertEq(liquidator_.penaltyWeight(), 5);
        assertEq(liquidator_.initiatorRewardWeight(), 1);
        assertEq(liquidator_.startPriceMultiplier(), 110);
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATOR OWNERSHIP
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        vm.prank(creatorAddress);
        liquidator_.transferOwnership(to);

        assertEq(to, liquidator_.owner());
    }

    function testRevert_transferOwnership_NonOwner(address unprivilegedAddress_, address to) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator_.transferOwnership(to);

        assertEq(creatorAddress, liquidator_.owner());
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    function testRevert_setWeights_NonOwner(
        address unprivilegedAddress_,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight
    ) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator_.setWeights(initiatorRewardWeight, penaltyWeight);
        vm.stopPrank();
    }

    function testRevert_setWeights_WeightsTooHigh(uint8 initiatorRewardWeight, uint8 penaltyWeight) public {
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight > 11);

        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SW: Weights Too High");
        liquidator_.setWeights(initiatorRewardWeight, penaltyWeight);
        vm.stopPrank();
    }

    function testSuccess_setWeights(uint8 initiatorRewardWeight, uint8 penaltyWeight) public {
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight <= 11);

        vm.prank(creatorAddress);
        liquidator_.setWeights(initiatorRewardWeight, penaltyWeight);

        assertEq(liquidator_.penaltyWeight(), penaltyWeight);
        assertEq(liquidator_.initiatorRewardWeight(), initiatorRewardWeight);
    }

    function testRevert_setAuctionCurveParameters_NonOwner(
        address unprivilegedAddress_,
        uint16 halfLifeTime,
        uint16 cutoffTime
    ) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_BaseTooHigh(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 8 * 60 * 60);

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SACP: halfLifeTime too high");
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_BaseTooLow(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime < 2 * 60);

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SACP: halfLifeTime too low");
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_AuctionCutoffTimeTooHigh(uint16 halfLifeTime, uint16 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);

        vm.assume(cutoffTime > 18 * 60 * 60);

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SACP: cutoff too high");
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_AuctionCutoffTimeTooLow(uint16 halfLifeTime, uint16 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);

        vm.assume(cutoffTime < 1 * 60 * 60);

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SACP: cutoff too low");
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_PowerFunctionReverts(uint8 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 15 * 60);
        vm.assume(cutoffTime > 10 * 60 * 60);
        vm.assume(cutoffTime < 18 * 60 * 60);

        vm.startPrank(creatorAddress);
        vm.expectRevert();
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testSuccess_setAuctionCurveParameters_Base(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);
        vm.assume(cutoffTime > 1 * 60 * 60);
        vm.assume(cutoffTime < 2 * 60 * 60);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the discount rate
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        // Then: the discount rate is correctly set
        uint256 expectedDiscountRate = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime));
        assertEq(liquidator_.base(), expectedDiscountRate);
    }

    function testSuccess_setAuctionCurveParameters_cutoffTime(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 1 * 60 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);
        vm.assume(cutoffTime > 1 * 60 * 60);
        vm.assume(cutoffTime < 8 * 60 * 60);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the max auction time
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        // Then: the max auction time is set
        assertEq(liquidator_.cutoffTime(), cutoffTime);
    }

    function testRevert_setStartPriceMultiplier_NonOwner(address unprivilegedAddress_, uint16 priceMultiplier) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator_.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testRevert_setStartPriceMultiplier_tooHigh(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier > 300);

        // Given When Then: a owner attempts to set the start price multiplier, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SSPM: multiplier too high");
        liquidator_.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testRevert_setStartPriceMultiplier_tooLow(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier < 100);

        // Given When Then: a owner attempts to set the start price multiplier, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SSPM: multiplier too low");
        liquidator_.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testSuccess_setStartPriceMultiplier(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier > 100);
        vm.assume(priceMultiplier < 301);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the start price multiplier
        liquidator_.setStartPriceMultiplier(priceMultiplier);
        // Then: multiplier sets correctly
        assertEq(liquidator_.startPriceMultiplier(), priceMultiplier);
    }

    function testRevert_setMinimumPriceMultiplier_tooHigh(uint8 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier >= 91);

        // Given When Then: a owner attempts to set the minimum price multiplier, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SMPM: multiplier too high");
        liquidator_.setMinimumPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testSuccess_setMinimumPriceMultiplier(uint8 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier < 91);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the minimum price multiplier
        liquidator_.setMinimumPriceMultiplier(priceMultiplier);
        // Then: multiplier sets correctly
        assertEq(liquidator_.minPriceMultiplier(), priceMultiplier);
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testRevert_startAuction_AuctionOngoing(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);

        vm.startPrank(address(pool));
        vm.expectRevert("LQ_SA: Auction already ongoing");
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);
        vm.stopPrank();
    }

    function testRevert_startAuction_NonCreditor(address unprivilegedAddress_, uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.assume(unprivilegedAddress_ != address(pool));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("LQ_SA: Unauthorised");
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);
        vm.stopPrank();
    }

    function testSuccess_startAuction(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);

        assertEq(proxy.owner(), address(liquidator_));
        {
            uint256 index = factory.vaultIndex(address(proxy));
            assertEq(factory.ownerOf(index), address(liquidator_));
        }

        {
            (uint128 openDebt_, uint32 startTime, bool inAuction, uint80 maxInitiatorFee, address baseCurrency) =
                liquidator_.getAuctionInformationPartOne(address(proxy));

            assertEq(openDebt_, openDebt);
            assertEq(startTime, uint128(block.timestamp));
            assertEq(inAuction, true);
            assertEq(maxInitiatorFee, pool.maxInitiatorFee());
            assertEq(baseCurrency, address(dai));
        }

        {
            (
                uint16 startPriceMultiplier,
                uint8 minPriceMultiplier,
                uint8 initiatorRewardWeight,
                uint8 penaltyWeight,
                uint16 cutoffTime,
                address originalOwner,
                address trustedCreditor,
                uint64 base
            ) = liquidator_.getAuctionInformationPartTwo(address(proxy));

            assertEq(startPriceMultiplier, liquidator_.startPriceMultiplier());
            assertEq(minPriceMultiplier, liquidator_.minPriceMultiplier());
            assertEq(initiatorRewardWeight, liquidator_.initiatorRewardWeight());
            assertEq(penaltyWeight, liquidator_.penaltyWeight());
            assertEq(cutoffTime, liquidator_.cutoffTime());
            assertEq(originalOwner, vaultOwner);
            assertEq(trustedCreditor, address(pool));
            assertEq(base, liquidator_.base());
        }
    }

    function testSuccess_startAuction_fixed() public {
        uint128 openDebt = 1000;
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);
    }

    function testSuccess_getPriceOfVault_NotForSale(address vaultAddress) public {
        (uint256 price, bool inAuction) = liquidator_.getPriceOfVault(vaultAddress);

        assertEq(price, 0);
        assertEq(inAuction, false);
    }

    function testSuccess_getPriceOfVault_BeforeCutOffTime(
        uint32 startTime,
        uint16 halfLifeTime,
        uint32 currentTime,
        uint16 cutoffTime,
        uint128 openDebt,
        uint8 startPriceMultiplier,
        uint8 minPriceMultiplier
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(currentTime - startTime < cutoffTime);
        vm.assume(openDebt > 0);
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);

        // Given: A vault is in auction
        uint64 base = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime)));

        vm.startPrank(creatorAddress);
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator_.setStartPriceMultiplier(startPriceMultiplier);
        liquidator_.setMinimumPriceMultiplier(minPriceMultiplier);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);
        vm.warp(currentTime);

        // When: Get the price of the vault
        (uint256 price, bool inAuction) = liquidator_.getPriceOfVault(address(proxy));

        // And: The price is calculated outside correctly
        uint256 auctionTime = (uint256(currentTime) - uint256(startTime)) * 1e18;
        uint256 multiplier = (startPriceMultiplier - minPriceMultiplier) * LogExpMath.pow(base, auctionTime)
            + 1e18 * uint256(minPriceMultiplier);
        uint256 expectedPrice = uint256(openDebt) * multiplier / 1e20;

        // Then: The price is calculated correctly
        assertEq(price, expectedPrice);
        assertEq(inAuction, true);
    }

    function testSuccess_getPriceOfVault_AfterCutOffTime(
        uint32 startTime,
        uint16 halfLifeTime,
        uint32 currentTime,
        uint16 cutoffTime,
        uint128 openDebt,
        uint8 startPriceMultiplier,
        uint8 minPriceMultiplier
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(currentTime - startTime >= cutoffTime);
        vm.assume(openDebt > 0);
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);

        // Given: A vault is in auction
        vm.startPrank(creatorAddress);
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator_.setStartPriceMultiplier(startPriceMultiplier);
        liquidator_.setMinimumPriceMultiplier(minPriceMultiplier);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);
        vm.warp(currentTime);

        // When: Get the price of the vault
        (uint256 price, bool inAuction) = liquidator_.getPriceOfVault(address(proxy));

        // And: The price is calculated outside correctly
        uint256 expectedPrice = uint256(openDebt) * minPriceMultiplier / 1e2;

        // Then: The price is calculated correctly
        assertEq(price, expectedPrice);
        assertEq(inAuction, true);
    }

    function testRevert_buyVault_notForSale(address bidder) public {
        vm.startPrank(bidder);
        vm.expectRevert("LQ_BV: Not for sale");
        liquidator_.buyVault(address(proxy));
        vm.stopPrank();
    }

    function testRevert_buyVault_InsufficientFunds(address bidder, uint128 openDebt, uint136 bidderfunds) public {
        vm.assume(openDebt > 0);
        vm.assume(bidder != address(pool));
        vm.assume(bidder != liquidityProvider);

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);

        (uint256 priceOfVault,) = liquidator_.getPriceOfVault(address(proxy));
        vm.assume(priceOfVault > bidderfunds);

        vm.prank(liquidityProvider);
        dai.transfer(bidder, bidderfunds);

        vm.startPrank(bidder);
        dai.approve(address(liquidator_), type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        liquidator_.buyVault(address(proxy));
        vm.stopPrank();
    }

    function testSuccess_buyVault(
        uint128 openDebt,
        uint136 bidderfunds,
        uint16 halfLifeTime,
        uint24 timePassed,
        uint16 cutoffTime,
        uint8 startPriceMultiplier,
        uint8 minPriceMultiplier
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);
        vm.assume(openDebt > 0 && openDebt <= pool.totalRealisedLiquidity());
        address bidder = address(69); //Cannot fuzz the bidder address, since any existing contract without onERC721Received will revert

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);

        vm.warp(block.timestamp + timePassed);

        (uint256 priceOfVault,) = liquidator_.getPriceOfVault(address(proxy));
        vm.assume(priceOfVault <= bidderfunds);

        vm.prank(liquidityProvider);
        dai.transfer(bidder, bidderfunds);

        uint256 totalRealisedLiquidityBefore = pool.totalRealisedLiquidity();
        uint256 availableLiquidityBefore = dai.balanceOf(address(pool));

        vm.startPrank(bidder);
        dai.approve(address(liquidator_), type(uint256).max);
        liquidator_.buyVault(address(proxy));
        vm.stopPrank();

        uint256 totalRealisedLiquidityAfter = pool.totalRealisedLiquidity();
        uint256 availableLiquidityAfter = dai.balanceOf(address(pool));

        if (priceOfVault >= openDebt) {
            assertEq(totalRealisedLiquidityAfter - totalRealisedLiquidityBefore, priceOfVault - openDebt);
        } else {
            assertEq(totalRealisedLiquidityBefore - totalRealisedLiquidityAfter, openDebt - priceOfVault);
        }
        assertEq(availableLiquidityAfter - availableLiquidityBefore, priceOfVault);
        assertEq(dai.balanceOf(bidder), bidderfunds - priceOfVault);
        uint256 index = factory.vaultIndex(address(proxy));
        assertEq(factory.ownerOf(index), bidder);
        assertEq(proxy.owner(), bidder);
    }

    function testSuccess_buyVault_fixed() public {
        uint128 openDebt = 1000;
        uint136 bidderfunds = 5000;
        uint16 halfLifeTime = (10 * 60) + 1;
        uint24 timePassed = 5;
        uint16 cutoffTime = 1 * 60 * 60 + 1;
        uint8 startPriceMultiplier = 250;
        uint8 minPriceMultiplier = 60;

        // Preprocess: Set up the fuzzed variables
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);
        vm.assume(openDebt > 0 && openDebt <= pool.totalRealisedLiquidity());
        address bidder = address(69); //Cannot fuzz the bidder address, since any existing contract without onERC721Received will revert

        vm.prank(address(pool));
        liquidator_.startAuction(address(proxy), openDebt, type(uint80).max);

        vm.warp(block.timestamp + timePassed);

        (uint256 priceOfVault,) = liquidator_.getPriceOfVault(address(proxy));
        vm.assume(priceOfVault <= bidderfunds);

        vm.prank(liquidityProvider);
        dai.transfer(bidder, bidderfunds);

        uint256 totalRealisedLiquidityBefore = pool.totalRealisedLiquidity();
        uint256 availableLiquidityBefore = dai.balanceOf(address(pool));

        vm.startPrank(bidder);
        dai.approve(address(liquidator_), type(uint256).max);
        liquidator_.buyVault(address(proxy));
        vm.stopPrank();

        uint256 totalRealisedLiquidityAfter = pool.totalRealisedLiquidity();
        uint256 availableLiquidityAfter = dai.balanceOf(address(pool));

        if (priceOfVault >= openDebt) {
            assertEq(totalRealisedLiquidityAfter - totalRealisedLiquidityBefore, priceOfVault - openDebt);
        } else {
            assertEq(totalRealisedLiquidityBefore - totalRealisedLiquidityAfter, openDebt - priceOfVault);
        }
        assertEq(availableLiquidityAfter - availableLiquidityBefore, priceOfVault);
        assertEq(dai.balanceOf(bidder), bidderfunds - priceOfVault);
        uint256 index = factory.vaultIndex(address(proxy));
        assertEq(factory.ownerOf(index), bidder);
        assertEq(proxy.owner(), bidder);
    }

    function testSuccess_calcLiquidationSettlementValues(uint128 openDebt, uint256 priceOfVault, uint88 maxInitiatorFee)
        public
    {
        uint8 penaltyWeight = liquidator_.penaltyWeight();
        uint8 initiatorRewardWeight = liquidator_.initiatorRewardWeight();
        uint256 expectedLiquidationInitiatorReward = uint256(openDebt) * initiatorRewardWeight / 100;
        expectedLiquidationInitiatorReward =
            expectedLiquidationInitiatorReward > maxInitiatorFee ? maxInitiatorFee : expectedLiquidationInitiatorReward;
        uint256 expectedBadDebt;
        uint256 expectedLiquidationPenalty;
        uint256 expectedRemainder;

        if (priceOfVault < expectedLiquidationInitiatorReward + openDebt) {
            expectedBadDebt = expectedLiquidationInitiatorReward + openDebt - priceOfVault;
        } else {
            expectedLiquidationPenalty = uint256(openDebt) * penaltyWeight / 100;
            expectedRemainder = priceOfVault - openDebt - expectedLiquidationInitiatorReward;

            if (expectedRemainder > expectedLiquidationPenalty) {
                expectedRemainder -= expectedLiquidationPenalty;
            } else {
                expectedLiquidationPenalty = expectedRemainder;
                expectedRemainder = 0;
            }
        }

        (
            uint256 actualBadDebt,
            uint256 actualLiquidationInitiatorReward,
            uint256 actualLiquidationPenalty,
            uint256 actualRemainder
        ) = liquidator_.calcLiquidationSettlementValues(openDebt, priceOfVault, maxInitiatorFee);

        assertEq(actualBadDebt, expectedBadDebt);
        assertEq(actualLiquidationInitiatorReward, expectedLiquidationInitiatorReward);
        assertEq(actualLiquidationPenalty, expectedLiquidationPenalty);
        assertEq(actualRemainder, expectedRemainder);
    }
}
