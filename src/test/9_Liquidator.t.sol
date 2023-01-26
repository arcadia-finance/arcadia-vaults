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
        pool.addTranche(address(tranche), 50);
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
        (uint64 protocol, uint64 liquidationInitiator_) = liquidator.claimRatios();
        assertEq(protocol, 5);
        assertEq(liquidationInitiator_, 2);
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

    function testRevert_setProtocolTreasury_NonOwner(address unprivilegedAddress_, address protocolTreasury_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setProtocolTreasury(protocolTreasury_);
        vm.stopPrank();
    }

    function testSuccess_setProtocolTreasury(address protocolTreasury_) public {
        vm.prank(creatorAddress);
        liquidator.setProtocolTreasury(protocolTreasury_);

        assertEq(liquidator.protocolTreasury(), protocolTreasury_);
    }

    function testRevert_setReserveFund_NonOwner(address unprivilegedAddress_, address reserveFund_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setReserveFund(reserveFund_);
        vm.stopPrank();
    }

    function testSuccess_setReserveFund(address reserveFund_) public {
        vm.prank(creatorAddress);
        liquidator.setReserveFund(reserveFund_);

        assertEq(liquidator.reserveFund(), reserveFund_);
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    function testRevert_setBreakevenTime_NonOwner(address unprivilegedAddress_, uint256 breakevenTime_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator.setBreakevenTime(breakevenTime_);
        vm.stopPrank();
    }

    function testSuccess_setBreakevenTime(uint256 breakevenTime_) public {
        vm.prank(creatorAddress);
        liquidator.setBreakevenTime(breakevenTime_);

        assertEq(liquidator.breakevenTime(), breakevenTime_);
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testRevert_startAuction_NonVault(
        address unprivilegedAddress_,
        address liquidationInitiator_,
        uint128 openDebt
    ) public {
        vm.assume(unprivilegedAddress_ != address(proxy));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("LQ_SA: Not a vault");
        liquidator.startAuction(liquidationInitiator_, vaultOwner, openDebt, address(dai), address(pool));
        vm.stopPrank();
    }

    function testRevert_startAuction_AuctionOngoing(address liquidationInitiator_, uint128 openDebt) public {
        vm.assume(openDebt > 0);
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(openDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(openDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxy)).checked_write(openDebt);

        vm.prank(address(proxy));
        liquidator.startAuction(liquidationInitiator_, vaultOwner, openDebt, address(dai), address(pool));

        vm.startPrank(address(proxy));
        vm.expectRevert("LQ_SA: Auction already ongoing");
        liquidator.startAuction(liquidationInitiator_, vaultOwner, openDebt, address(dai), address(pool));
        vm.stopPrank();
    }

    function testSuccess_startAuction(address liquidationInitiator_, uint128 openDebt) public {
        vm.assume(openDebt > 0);
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(openDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(openDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxy)).checked_write(openDebt);

        vm.prank(address(proxy));
        liquidator.startAuction(liquidationInitiator_, vaultOwner, openDebt, address(dai), address(pool));

        uint256 openClaim = liquidator.calcLiquidationInitiatorReward(openDebt);
        assertEq(liquidator.openClaims(liquidationInitiator_, address(dai)), openClaim);

        (
            uint128 openDebt_,
            uint128 startBlock,
            bool inAuction,
            address baseCurrency,
            address originalOwner,
            address trustedCreditor
        ) = liquidator.auctionInformation(address(proxy));
        assertEq(openDebt_, openDebt);
        assertEq(startBlock, uint128(block.number));
        assertEq(inAuction, true);
        assertEq(baseCurrency, address(dai));
        assertEq(originalOwner, vaultOwner);
        assertEq(trustedCreditor, address(pool));
    }

    /*///////////////////////////////////////////////////////////////
                    CLAIM AUCTION PROCEEDS
    ///////////////////////////////////////////////////////////////*/

    function testRevert_claim_InsufficientOpenClaims(
        address claimer,
        uint128 openClaim,
        uint128 claimAmount,
        uint128 liquidatorBalance
    ) public {
        vm.assume(claimAmount > openClaim);

        vm.prank(liquidityProvider);
        dai.transfer(address(liquidator), liquidatorBalance);

        stdstore.target(address(liquidator)).sig(liquidator.openClaims.selector).with_key(claimer).with_key(
            address(dai)
        ).checked_write(openClaim);

        vm.startPrank(claimer);
        vm.expectRevert(stdError.arithmeticError);
        liquidator.claim(address(dai), claimAmount);
        vm.stopPrank();
    }

    function testRevert_claim_InsufficientBalanceLiquidator(
        address claimer,
        uint128 openClaim,
        uint128 claimAmount,
        uint128 liquidatorBalance
    ) public {
        vm.assume(claimAmount <= openClaim);
        vm.assume(claimAmount > liquidatorBalance);

        vm.prank(liquidityProvider);
        dai.transfer(address(liquidator), liquidatorBalance);

        stdstore.target(address(liquidator)).sig(liquidator.openClaims.selector).with_key(claimer).with_key(
            address(dai)
        ).checked_write(openClaim);

        vm.startPrank(claimer);
        vm.expectRevert(stdError.arithmeticError);
        liquidator.claim(address(dai), claimAmount);
        vm.stopPrank();
    }

    function testSuccess_claim(address claimer, uint128 openClaim, uint128 claimAmount, uint128 liquidatorBalance)
        public
    {
        vm.assume(claimAmount <= openClaim);
        vm.assume(claimAmount <= liquidatorBalance);
        vm.assume(claimer != liquidityProvider);

        vm.prank(liquidityProvider);
        dai.transfer(address(liquidator), liquidatorBalance);

        stdstore.target(address(liquidator)).sig(liquidator.openClaims.selector).with_key(claimer).with_key(
            address(dai)
        ).checked_write(openClaim);

        vm.prank(claimer);
        liquidator.claim(address(dai), claimAmount);

        assertEq(liquidator.openClaims(claimer, address(dai)), openClaim - claimAmount);
        assertEq(dai.balanceOf(claimer), claimAmount);
        assertEq(dai.balanceOf(address(liquidator)), liquidatorBalance - claimAmount);
    }

    /*///////////////////////////////////////////////////////////////
                            OLD TESTS
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getPriceOfVault(uint128 amountEth, uint256 newPrice) public {
        uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin());

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidationInitiator);
        factory.liquidate(address(proxy));

        uint16 liqThres = 150;

        (uint256 vaultPrice,, bool forSale) = liquidator.getPriceOfVault(address(proxy));

        uint256 expectedPrice = (amountCredit * liqThres) / 100;
        assertTrue(forSale);
        assertEq(vaultPrice, expectedPrice);
    }

    function testSuccess_liquidate_AuctionPriceDecrease(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll)
        public
    {
        vm.assume(blocksToRoll < liquidator.hourlyBlocks() * liquidator.breakevenTime());
        uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin());

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidationInitiator);
        factory.liquidate(address(proxy));

        (uint128 openDebt,,,,,) = liquidator.auctionInformation(address(proxy));
        uint16 liqThres = 150;
        (uint256 vaultPriceBefore,, bool forSaleBefore) = liquidator.getPriceOfVault(address(proxy));

        vm.roll(block.number + blocksToRoll);
        (uint256 vaultPriceAfter,, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy));

        uint256 expectedPrice = ((openDebt * liqThres) / 100)
            - (
                (blocksToRoll * ((openDebt * (liqThres - 100)) / 100))
                    / (liquidator.hourlyBlocks() * liquidator.breakevenTime())
            );

        emit log_named_uint("expectedPrice", expectedPrice);

        assertTrue(forSaleBefore);
        assertTrue(forSaleAfter);
        assertGe(vaultPriceBefore, vaultPriceAfter);
        assertEq(vaultPriceAfter, expectedPrice);
    }

    function testSuccess_buyVault(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
        vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.breakevenTime());
        uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin());

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidationInitiator);
        factory.liquidate(address(proxy));

        (uint256 priceOfVault,,) = liquidator.getPriceOfVault(address(proxy));
        giveAsset(auctionBuyer, priceOfVault);

        vm.prank(auctionBuyer);
        liquidator.buyVault(address(proxy));

        assertEq(proxy.owner(), auctionBuyer); //todo: check erc721 owner
    }

    function testSuccess_withdraw_FromPurchasedVault(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll) public {
        vm.assume(blocksToRoll > liquidator.hourlyBlocks() * liquidator.breakevenTime());
        uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        ) = depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin());

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidationInitiator);
        factory.liquidate(address(proxy));

        (uint256 priceOfVault,,) = liquidator.getPriceOfVault(address(proxy));
        giveAsset(auctionBuyer, priceOfVault);

        vm.prank(auctionBuyer);
        liquidator.buyVault(address(proxy));

        assertEq(proxy.owner(), auctionBuyer);

        vm.startPrank(auctionBuyer);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(proxy), auctionBuyer, assetAmounts[0]);
        proxy.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testSuccess_Breakeven(uint128 amountEth, uint256 newPrice, uint64 blocksToRoll, uint8 breakevenTime)
        public
    {
        vm.assume(blocksToRoll < liquidator.hourlyBlocks() * breakevenTime);
        uint16 collFactorProxy = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16 liqFactorProxy = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        vm.assume(newPrice / 100 * liqFactorProxy < rateEthToUsd / 100 * collFactorProxy);
        vm.assume(amountEth > 0);
        uint256 valueOfOneEth = rateEthToUsd * 10 ** (Constants.usdDecimals - Constants.oracleEthToUsdDecimals);
        vm.assume(amountEth < type(uint128).max / valueOfOneEth);

        depositERC20InVault(eth, amountEth, vaultOwner);

        uint128 amountCredit = uint128(proxy.getFreeMargin());

        vm.prank(vaultOwner);
        pool.borrow(amountCredit, address(proxy), vaultOwner, emptyBytes3);

        vm.prank(creatorAddress);
        liquidator.setBreakevenTime(breakevenTime);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.prank(liquidationInitiator);
        factory.liquidate(address(proxy));

        (uint128 openDebt,,,,,) = liquidator.auctionInformation(address(proxy));
        uint16 liqThres = 150;
        (uint256 vaultPriceBefore,, bool forSaleBefore) = liquidator.getPriceOfVault(address(proxy));

        vm.roll(block.number + blocksToRoll);
        (uint256 vaultPriceAfter,, bool forSaleAfter) = liquidator.getPriceOfVault(address(proxy));

        uint256 expectedPrice = ((openDebt * liqThres) / 100)
            - ((blocksToRoll * ((openDebt * (liqThres - 100)) / 100)) / (liquidator.hourlyBlocks() * breakevenTime));

        emit log_named_uint("expectedPrice", expectedPrice);

        assertTrue(forSaleBefore);
        assertTrue(forSaleAfter);
        assertGe(vaultPriceBefore, vaultPriceAfter);
        assertEq(vaultPriceAfter, expectedPrice);
    }

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
