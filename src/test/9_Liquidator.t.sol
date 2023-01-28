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

contract LiquidatorTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    bytes3 public emptyBytes3;

    address private liquidationInitiator = address(8);
    address private auctionBuyer = address(9);

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(
            address(factory),
            address(mainRegistry)
        );
        liquidator.setFactory(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));
        pool.setVaultVersion(1, true);
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
        dai.approve(address(liquidator), type(uint256).max);
    }

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */
    function testSuccess_deployment() public {
        assertEq(liquidator.factory(), address(factory));
        assertEq(liquidator.registry(), address(mainRegistry));
        (uint64 penalty, uint64 initiatorReward) = liquidator.claimRatios();
        assertEq(penalty, 5);
        assertEq(initiatorReward, 2);
        assertEq(liquidator.startPriceMultiplier(), 110);
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATOR OWNERSHIP
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        vm.prank(creatorAddress);
        liquidator.transferOwnership(to);

        assertEq(to, liquidator.owner());
    }

    function testRevert_transferOwnership_NonOwner(address unprivilegedAddress_, address to) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.transferOwnership(to);

        assertEq(creatorAddress, liquidator.owner());
    }

    /*///////////////////////////////////////////////////////////////
                          EXTERNAL CONTRACTS
    ///////////////////////////////////////////////////////////////*/

    function testRevert_setFactory_NonOwner(address unprivilegedAddress_, address factory_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setFactory(factory_);
        vm.stopPrank();
    }

    function testSuccess_setFactory(address factory_) public {
        vm.prank(creatorAddress);
        liquidator.setFactory(factory_);

        assertEq(liquidator.factory(), factory_);
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    function testRevert_setClaimRatios_NonOwner(
        address unprivilegedAddress_,
        Liquidator.ClaimRatios memory claimRatios_
    ) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setClaimRatios(claimRatios_);
        vm.stopPrank();
    }

    function testSuccess_setClaimRatios(Liquidator.ClaimRatios memory claimRatios_) public {
        vm.prank(creatorAddress);
        liquidator.setClaimRatios(claimRatios_);

        (uint64 penalty, uint64 initiatorReward) = liquidator.claimRatios();
        assertEq(penalty, claimRatios_.penalty);
        assertEq(initiatorReward, claimRatios_.initiatorReward);
    }

    function testRevert_setMaxAuctionTime_NonOwner(address unprivilegedAddress_, uint256 maxAuctionTime_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setMaxAuctionTime(maxAuctionTime_);
        vm.stopPrank();
    }

    function testSuccess_setMaxAuctionTime(uint256 maxAuctionTime_) public {
        vm.prank(creatorAddress);
        liquidator.setMaxAuctionTime(maxAuctionTime_);

        assertEq(liquidator.maxAuctionTime(), maxAuctionTime_);
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testRevert_startAuction_AuctionOngoing(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);

        vm.startPrank(address(pool));
        vm.expectRevert("LQ_SA: Auction already ongoing");
        liquidator.startAuction(address(proxy), openDebt);
        vm.stopPrank();
    }

    function testRevert_startAuction_NonVault(address unprivilegedAddress_, uint128 openDebt) public {
        vm.assume(unprivilegedAddress_ != address(proxy));

        vm.startPrank(address(pool));
        vm.expectRevert("LQ_SA: Not a vault");
        liquidator.startAuction(unprivilegedAddress_, openDebt);
        vm.stopPrank();
    }

    function testRevert_startAuction_NonCreditor(address unprivilegedAddress_, uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.assume(unprivilegedAddress_ != address(pool));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("LQ_SA: Unauthorised");
        liquidator.startAuction(address(proxy), openDebt);
        vm.stopPrank();
    }

    function testSuccess_startAuction(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);

        assertEq(proxy.owner(), address(liquidator));
        uint256 index = factory.vaultIndex(address(proxy));
        assertEq(factory.ownerOf(index), address(liquidator));

        (
            uint128 openDebt_,
            uint128 startTime,
            bool inAuction,
            address baseCurrency,
            address originalOwner,
            address trustedCreditor
        ) = liquidator.auctionInformation(address(proxy));
        assertEq(openDebt_, openDebt);
        assertEq(startTime, uint128(block.timestamp));
        assertEq(inAuction, true);
        assertEq(baseCurrency, address(dai));
        assertEq(originalOwner, vaultOwner);
        assertEq(trustedCreditor, address(pool));
    }

    function testSuccess_getPriceOfVault_NotForSale(address vaultAddress) public {
        (uint256 price, bool inAuction) = liquidator.getPriceOfVault(vaultAddress);

        assertEq(price, 0);
        assertEq(inAuction, false);
    }

    function testSuccess_getPriceOfVault_AuctionTimeExceedingMaxTime(
        uint64 startTime,
        uint64 maxAuctionTime,
        uint64 currentTime,
        uint128 openDebt
    ) public {
        vm.assume(currentTime > startTime);
        vm.assume(currentTime - startTime > maxAuctionTime);

        vm.assume(openDebt > 0);

        stdstore.target(address(liquidator)).sig(liquidator.maxAuctionTime.selector).checked_write(maxAuctionTime);
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);
        vm.warp(currentTime);

        (uint256 price, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        assertEq(price, 0);
        assertEq(inAuction, true);
    }

    function testSuccess_getPriceOfVault_AuctionTimeUnderMaxTime(
        uint64 startTime,
        uint64 maxAuctionTime,
        uint64 currentTime,
        uint128 openDebt,
        uint8 startPriceMultiplier_
    ) public {
        vm.assume(currentTime > startTime);
        vm.assume(currentTime - startTime <= maxAuctionTime);

        vm.assume(openDebt > 0);

        stdstore.target(address(liquidator)).sig(liquidator.maxAuctionTime.selector).checked_write(maxAuctionTime);
        stdstore.target(address(liquidator)).sig(liquidator.startPriceMultiplier.selector).checked_write(
            startPriceMultiplier_
        );
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);
        vm.warp(currentTime);

        uint256 auctionTime = currentTime - startTime;
        uint256 startPrice = uint256(openDebt) * startPriceMultiplier_; //2 decimals
        uint256 expectedPrice = startPrice * (maxAuctionTime - auctionTime) / maxAuctionTime; //2 decimals
        expectedPrice = expectedPrice / 100; //0 decimals

        (uint256 actualPrice, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        assertEq(actualPrice, expectedPrice);
        assertEq(inAuction, true);
    }

    function testRevert_buyVault_notForSale(address bidder) public {
        vm.startPrank(bidder);
        vm.expectRevert("LQ_BV: Not for sale");
        liquidator.buyVault(address(proxy));
        vm.stopPrank();
    }

    function testRevert_buyVault_InsufficientFunds(address bidder, uint128 openDebt, uint136 bidderfunds) public {
        vm.assume(openDebt > 0);
        vm.assume(bidder != address(pool));
        vm.assume(bidder != liquidityProvider);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);

        (uint256 priceOfVault,) = liquidator.getPriceOfVault(address(proxy));
        vm.assume(priceOfVault > bidderfunds);

        vm.prank(liquidityProvider);
        dai.transfer(bidder, bidderfunds);

        vm.startPrank(bidder);
        dai.approve(address(liquidator), type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        liquidator.buyVault(address(proxy));
        vm.stopPrank();
    }

    function testSuccess_buyVault(uint128 openDebt, uint136 bidderfunds) public {
        vm.assume(openDebt > 0);
        address bidder = address(69); //Cannot fuzz the bidder address, since any existing contract without onERC721Received will revert

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);

        (uint256 priceOfVault,) = liquidator.getPriceOfVault(address(proxy));
        vm.assume(priceOfVault <= bidderfunds);

        vm.prank(liquidityProvider);
        dai.transfer(bidder, bidderfunds);

        uint256 totalRealisedLiquidityBefore = pool.totalRealisedLiquidity();
        uint256 availableLiquidityBefore = dai.balanceOf(address(pool));

        vm.startPrank(bidder);
        dai.approve(address(liquidator), type(uint256).max);
        liquidator.buyVault(address(proxy));
        vm.stopPrank();

        uint256 totalRealisedLiquidityAfter = pool.totalRealisedLiquidity();
        uint256 availableLiquidityAfter = dai.balanceOf(address(pool));

        assertEq(totalRealisedLiquidityAfter - totalRealisedLiquidityBefore, priceOfVault - openDebt);
        assertEq(availableLiquidityAfter - availableLiquidityBefore, priceOfVault);
        assertEq(dai.balanceOf(bidder), bidderfunds - priceOfVault);
        uint256 index = factory.vaultIndex(address(proxy));
        assertEq(factory.ownerOf(index), bidder);
        assertEq(proxy.owner(), bidder);
    }

    function testSuccess_calcLiquidationSettlementValues(uint128 openDebt, uint256 priceOfVault) public {
        (uint64 penaltyWeight, uint64 initiatorRewardWeight) = liquidator.claimRatios();
        uint256 expectedLiquidationInitiatorReward = uint256(openDebt) * initiatorRewardWeight / 100;
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
        ) = liquidator.calcLiquidationSettlementValues(openDebt, priceOfVault);

        assertEq(actualBadDebt, expectedBadDebt);
        assertEq(actualLiquidationInitiatorReward, expectedLiquidationInitiatorReward);
        assertEq(actualLiquidationPenalty, expectedLiquidationPenalty);
        assertEq(actualRemainder, expectedRemainder);
    }
}
