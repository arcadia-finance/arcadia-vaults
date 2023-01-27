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
        vm.assume(unprivilegedAddress_ != address(pool));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("LQ_SA: Unauthorised");
        liquidator.startAuction(address(proxy), openDebt);
        vm.stopPrank();
    }

    function testSuccess_startAuction(uint128 openDebt) public {
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
        address liquidationInitiator_,
        uint128 openDebt
    ) public {
        vm.assume(currentTime > startTime);
        vm.assume(currentTime - startTime > maxAuctionTime);

        stdstore.target(address(liquidator)).sig(liquidator.maxAuctionTime.selector).checked_write(maxAuctionTime);
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy));
        vm.warp(currentTime);

        (uint256 price, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        assertEq(price, 0);
        assertEq(inAuction, true);
    }

    function testSuccess_getPriceOfVault_AuctionTimeUnderMaxTime(
        uint64 startTime,
        uint64 maxAuctionTime,
        uint64 currentTime,
        address liquidationInitiator_,
        uint128 openDebt,
        uint8 startPriceMultiplier_
    ) public {
        vm.assume(currentTime > startTime);
        vm.assume(currentTime - startTime <= maxAuctionTime);

        stdstore.target(address(liquidator)).sig(liquidator.maxAuctionTime.selector).checked_write(maxAuctionTime);
        stdstore.target(address(liquidator)).sig(liquidator.startPriceMultiplier.selector).checked_write(
            startPriceMultiplier_
        );
        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxy));
        vm.warp(currentTime);

        uint256 auctionTime = currentTime - startTime;
        uint256 startPrice = uint256(openDebt) * startPriceMultiplier_; //2 decimals
        uint256 expectedPrice = startPrice * (maxAuctionTime - auctionTime) / maxAuctionTime; //2 decimals
        expectedPrice = expectedPrice / 100; //0 decimals

        (uint256 actualPrice, bool inAuction) = liquidator.getPriceOfVault(address(proxy));

        assertEq(actualPrice, expectedPrice);
        assertEq(inAuction, true);
    }

    function testRevert_buyVault_notForSale() public {}

    function testSuccess_buyVault_Deficit() public {}

    function testSuccess_buyVault_BadDebt() public {}

    function testSuccess_buyVault_Penalty() public {}

    function testSuccess_buyVault_Remainder() public {}

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
