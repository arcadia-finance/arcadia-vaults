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
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
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

    function testRevert_setMaxAuctionTime_NonOwner(address unprivilegedAddress_, uint256 cutoffTime) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setAuctionCutoffTime(cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setMaxAuctionTime_NotInLimits(uint256 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(cutoffTime > 8 * 60 * 60 || cutoffTime < 1 * 60 * 60);

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_ACT: It must be in limits");
        liquidator.setAuctionCutoffTime(cutoffTime);
        vm.stopPrank();
    }

    function testSuccess_setMaxAuctionTime(uint256 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(cutoffTime > 1 * 60 * 60);
        vm.assume(cutoffTime < 8 * 60 * 60);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the max auction time
        liquidator.setAuctionCutoffTime(cutoffTime);
        // Then: the max auction time is set
        assertEq(liquidator.auctionCutoffTime(), cutoffTime);
    }

    function testRevert_setDiscountRate_NonOwner(address unprivilegedAddress_, uint256 halfLife) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setDiscountRate(halfLife);
        vm.stopPrank();
    }

    function testRevert_setDiscountRate_NotInLimits(uint256 halfLife) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLife > 8 * 60 * 60 || halfLife < 30 * 60);

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_DR: It must be in limits");
        liquidator.setDiscountRate(halfLife);
        vm.stopPrank();
    }

    function testSuccess_setDiscountRate(uint256 halfLife) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLife > 1 * 60 * 60);
        vm.assume(halfLife < 8 * 60 * 60);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the discount rate
        liquidator.setDiscountRate(halfLife);
        // Then: the discount rate is correctly set
        uint256 expectedDiscountRate = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLife));
        assertEq(liquidator.discountRate(), expectedDiscountRate);
    }

    function testRevert_setStartPriceMultiplier_NonOwner(address unprivilegedAddress_, uint16 priceMultiplier) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testRevert_setStartPriceMultiplier_NotInLimits(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier > 300 || priceMultiplier < 100);

        // Given When Then: a owner attempts to set the start price multiplier, but it is not in the limits
        vm.startPrank(creatorAddress);
        vm.expectRevert("LQ_SPM: It must be in limits");
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testSuccess_setStartPriceMultiplier(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier > 100);
        vm.assume(priceMultiplier < 301);
        // Given: the owner is the creatorAddress
        vm.prank(creatorAddress);
        // When: the owner sets the start price multiplier
        liquidator.setStartPriceMultiplier(priceMultiplier);
        // Then: multiplier sets correctly
        assertEq(liquidator.startPriceMultiplier(), priceMultiplier);
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

    function testSuccess_getPriceOfVault_AuctionTimeExceedsMaxTime(
        uint64 startTime,
        uint64 halfLife,
        uint64 currentTime,
        uint64 cutoffTime,
        uint128 openDebt
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLife > 1 * 60 * 60); // 1 hour
        vm.assume(halfLife < 4 * 60 * 60); // 4 hours
        vm.assume(cutoffTime < 1 * 24 * 60 * 60); // 3 day
        vm.assume(currentTime - startTime < 5 * 24 * 60 * 60); // 5 day
        vm.assume(currentTime - startTime > cutoffTime);
        vm.assume(openDebt > 0);

        // Given: A vault is in auction
        stdstore.target(address(liquidator)).sig(liquidator.auctionCutoffTime.selector).checked_write(cutoffTime);
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);
        vm.warp(currentTime);

        // When: Get the price of the vault
        (uint256 price, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        // Then: The price is calculated correctly
        assertEq(price, 0);
        assertEq(inAuction, false);
    }

    function testSuccess_getPriceOfVault_AuctionTimeUnderMaxTime(
        uint64 startTime,
        uint64 halfLife,
        uint64 currentTime,
        uint64 cutoffTime,
        uint128 openDebt
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLife > 1 * 60 * 60); // 1 hour
        vm.assume(halfLife < 4 * 60 * 60); // 4 hours
        vm.assume(cutoffTime > 5 * 24 * 60 * 60); // 1 day
        vm.assume(currentTime - startTime < 5 * 24 * 60 * 60); // 5 day
        vm.assume(openDebt > 0);

        // Given: A vault is in auction
        uint256 discountRate = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLife));

        stdstore.target(address(liquidator)).sig(liquidator.discountRate.selector).checked_write(discountRate);
        stdstore.target(address(liquidator)).sig(liquidator.auctionCutoffTime.selector).checked_write(cutoffTime);
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy), openDebt);
        vm.warp(currentTime);

        // When: Get the price of the vault
        (uint256 price, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        // And: The price is calculated outside correctly
        uint256 auctionTime = (uint256(currentTime) - uint256(startTime)) * 1e18;
        uint256 expectedPrice =
            uint256(openDebt) * liquidator.startPriceMultiplier() * LogExpMath.pow(discountRate, auctionTime) / 1e20;

        // Then: The price is calculated correctly
        assertEq(price, expectedPrice);
        assertEq(inAuction, true);
    }

    function testRevert_buyVault_notForSale() public {}

    function testRevert_buyVault_InsufficientFunds() public {}

    function testSuccess_buyVault() public {}

    function testSuccess_calcLiquidationSettlementValues() public {}

    // function testSuccess_calcLiquidationInitiatorReward(uint128 openDebt, uint8 initiatorReward_) public {
    //     vm.assume(initiatorReward_ <= 100);

    //     vm.prank(creatorAddress);
    //     liquidator.setClaimRatios(Liquidator.ClaimRatios({penalty: 0, initiatorReward: initiatorReward_}));

    //     uint256 expectedReward = uint256(openDebt) * initiatorReward_ / 100;
    //     uint256 actualReward = liquidator.calcLiquidationInitiatorReward(openDebt);

    //     assertEq(actualReward, expectedReward);
    // }

    // /*///////////////////////////////////////////////////////////////
    //                         OLD TESTS
    // ///////////////////////////////////////////////////////////////*/

    // function xtestSuccess_getPriceOfVault(uint128 amountEth, uint256 newPrice) public {
    //     uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    //     uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
    //     vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
    //     vm.assume(amountEth > 0);
    //     uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    //     vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    //     depositERC20InVault(eth, amountEth, vaultOwner);

    //     uint128 amountCredit = uint128(proxy.getFreeMargin());

    //     vm.prank(vaultOwner);
    //     pool.borrow(amountCredit, address(proxy), vaultOwner);

    //     vm.prank(oracleOwner);
    //     oracleEthToUsd.transmit(int256(newPrice));

    //     vm.prank(liquidationInitiator);
    //     factory.liquidate(address(proxy));

    //     uint16 liqThres = 150;

    //     (uint256 vaultPrice,, bool forSale) = liquidator.getPriceOfVault(address(proxy));

    //     uint256 expectedPrice = (amountCredit * liqThres) / 100;
    //     assertTrue(forSale);
    //     assertEq(vaultPrice, expectedPrice);
    // }

    // function xtestSuccess_liquidate_AuctionPriceDecrease(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll)
    //     public
    // {
    //     vm.assume(blocksToRoll < liquidator.hourlyBlocks() * liquidator.breakevenTime());
    //     uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    //     uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
    //     vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
    //     vm.assume(amountEth > 0);
    //     uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    //     vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    //     depositERC20InVault(eth, amountEth, vaultOwner);

    //     uint128 amountCredit = uint128(proxy.getFreeMargin());

    //     vm.prank(vaultOwner);
    //     pool.borrow(amountCredit, address(proxy), vaultOwner);

    //     vm.prank(oracleOwner);
    //     oracleEthToUsd.transmit(int256(newPrice));

    //     vm.prank(liquidationInitiator);
    //     factory.liquidate(address(proxy));

    //     (uint128 openDebt,,,,,) = liquidator.auctionInformation(address(proxy));
    //     uint16 liqThres = 150;
    //     (uint256 vaultPriceBefore,, bool forSaleBefore) = liquidator.getPriceOfVault(address(proxy));

    //     vm.roll(block.number + blocksToRoll);
    //     (uint256 vaultPriceAfter,, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy));

    //     uint256 expectedPrice = ((openDebt * liqThres) / 100)
    //         - (
    //             (blocksToRoll * ((openDebt * (liqThres - 100)) / 100))
    //                 / (liquidator.hourlyBlocks() * liquidator.breakevenTime())
    //         );

    //     emit log_named_uint("expectedPrice", expectedPrice);

    //     assertTrue(forSaleBefore);
    //     assertTrue(forSaleAfter);
    //     assertGe(vaultPriceBefore, vaultPriceAfter);
    //     assertEq(vaultPriceAfter, expectedPrice);
    // }

    // function xtestSuccess_buyVault(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
    //     vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.breakevenTime());
    //     uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    //     uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
    //     vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
    //     vm.assume(amountEth > 0);
    //     uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    //     vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    //     depositERC20InVault(eth, amountEth, vaultOwner);

    //     uint128 amountCredit = uint128(proxy.getFreeMargin());

    //     vm.prank(vaultOwner);
    //     pool.borrow(amountCredit, address(proxy), vaultOwner);

    //     vm.prank(oracleOwner);
    //     oracleEthToUsd.transmit(int256(newPrice));

    //     vm.prank(liquidationInitiator);
    //     factory.liquidate(address(proxy));

    //     (uint256 priceOfVault,,) = liquidator.getPriceOfVault(address(proxy));
    //     giveAsset(auctionBuyer, priceOfVault);

    //     vm.prank(auctionBuyer);
    //     liquidator.buyVault(address(proxy));

    //     assertEq(proxy.owner(), auctionBuyer); //todo: check erc721 owner
    // }

    // function xtestSuccess_Breakeven(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll, uint8 breakevenTime)
    //     public
    // {
    //     vm.assume(blocksToRoll < liquidator.hourlyBlocks() * breakevenTime);
    //     uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    //     uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
    //     vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
    //     vm.assume(amountEth > 0);
    //     uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
    //     vm.assume(amountEth < type(uint128).max / valueOfOneEth);

    //     depositERC20InVault(eth, amountEth, vaultOwner);

    //     uint128 amountCredit = uint128(proxy.getFreeMargin());

    //     vm.prank(vaultOwner);
    //     pool.borrow(amountCredit, address(proxy), vaultOwner);

    //     vm.prank(creatorAddress);
    //     liquidator.setBreakevenTime(breakevenTime);

    //     vm.prank(oracleOwner);
    //     oracleEthToUsd.transmit(int256(newPrice));

    //     vm.prank(liquidationInitiator);
    //     factory.liquidate(address(proxy));

    //     (uint128 openDebt,,,,,) = liquidator.auctionInformation(address(proxy));
    //     uint16 liqThres = 150;
    //     (uint256 vaultPriceBefore,, bool forSaleBefore) = liquidator.getPriceOfVault(address(proxy));

    //     vm.roll(block.number + blocksToRoll);
    //     (uint256 vaultPriceAfter,, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy));

    //     uint256 expectedPrice = ((openDebt * liqThres) / 100)
    //         - ((blocksToRoll * ((openDebt * (liqThres - 100)) / 100)) / (liquidator.hourlyBlocks() * breakevenTime));

    //     emit log_named_uint("expectedPrice", expectedPrice);

    //     assertTrue(forSaleBefore);
    //     assertTrue(forSaleAfter);
    //     assertGe(vaultPriceBefore, vaultPriceAfter);
    //     assertEq(vaultPriceAfter, expectedPrice);
    // }

    function giveAsset(address addr, uint256 amount) public {
        uint256 slot = stdstore.target(address(dai)).sig(dai.balanceOf.selector).with_key(addr).find();
        bytes32 loc = bytes32(slot);
        bytes32 newBalance = bytes32(abi.encode(amount));
        vm.store(address(dai), loc, newBalance);
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
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC721InVault(ERC721Mock token, uint128[] memory tokenIds, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);
        assetTypes = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.ownerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function depositERC1155InVault(ERC1155Mock token, uint256 tokenId, uint256 amount, address sender)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetTypes = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;
        assetTypes[0] = 2;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }
}
