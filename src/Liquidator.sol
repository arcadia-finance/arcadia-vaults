// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IFactory.sol";
import "./interfaces/IMainRegistry.sol";
import "./interfaces/IStable.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IReserveFund.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract Liquidator is Ownable {

  address public factoryAddress;
  address public registryAddress;
  address public reserveFund;
  address public protocolTreasury;

  uint256 constant public hourlyBlocks = 300;
  uint256 public auctionDuration = 6; //hours

  claimRatios public claimRatio;

  struct claimRatios {
    uint64 protocol;
    uint64 liquidationKeeper;
    uint64 reserveFund;
  }

  struct auctionInformation {
    uint128 openDebt;
    uint128 startBlock;
    uint8 liqThres;
    uint8 numeraire;
    uint128 stablePaid;
    address liquidationKeeper;
    address originalOwner;
  }

  mapping (address => mapping (uint256 => auctionInformation)) public auctionInfo;
  mapping (address => mapping (uint256 => uint256)) public claimableBitmap;

  constructor(address newFactory, address newRegAddr) {
    factoryAddress = newFactory;
    registryAddress = newRegAddr;
    claimRatio = claimRatios({protocol: 15, liquidationKeeper: 5, reserveFund: 5});
  }

  modifier elevated() {
    require(IFactory(factoryAddress).isVault(msg.sender), "LQ: Not a vault!");
    _;
  }

  function setFactory(address newFactory) external onlyOwner {
    factoryAddress = newFactory;
  }

  function setProtocolTreasury(address newProtocolTreasury) external onlyOwner {
    protocolTreasury = newProtocolTreasury;
  }

  function setReserveFund(address newReserveFund) external onlyOwner {
    reserveFund = newReserveFund;
  }

  //function startAuction() modifier = only by vault
  //  sets time start to now()
  //  stores the liquidationKeeper
  // 

  function startAuction(address vaultAddress, uint256 life, address liquidationKeeper, address originalOwner, uint128 openDebt, uint8 liqThres, uint8 numeraire) public elevated returns (bool) {

    require(auctionInfo[vaultAddress][life].startBlock == 0, "Liquidation already ongoing");

    auctionInfo[vaultAddress][life].startBlock = uint128(block.number);
    auctionInfo[vaultAddress][life].liquidationKeeper = liquidationKeeper;
    auctionInfo[vaultAddress][life].originalOwner = originalOwner;
    auctionInfo[vaultAddress][life].openDebt = openDebt;
    auctionInfo[vaultAddress][life].liqThres = liqThres;
    auctionInfo[vaultAddress][life].numeraire = numeraire;

    return true;
  }

  //function getPrice(assets) view
  // gets the price of assets, equals to oracle price + factor depending on time
   /** 
    @notice Function to check what the value of the items in the vault is.
    @dev 
    @param assetAddresses the vaultAddress 
    @param assetIds the vaultAddress 
    @param assetAmounts the vaultAddress 
  */
  function getPriceOfAssets(address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts, uint8 numeraireOfDebt) public view returns (uint256) {
    uint256 totalValue = IMainRegistry(registryAddress).getTotalValue(assetAddresses, assetIds, assetAmounts, numeraireOfDebt);
    return totalValue;
  }

  // gets the price of assets, equals to oracle price + factor depending on time
   /** 
    @notice Function to buy only a certain asset of a vault in the liquidation process
    @dev 
    @param assetAddresses the vaultAddress 
    @param assetIds the vaultAddress 
    @param assetAmounts the vaultAddress 
  */
  function buyPart(address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) public {

  }
   /** 
    @notice Function to check what the current price of the vault being auctioned of is.
    @dev 
    @param vaultAddress the vaultAddress 
  */
  function getPriceOfVault(address vaultAddress, uint256 life) public view returns (uint256, uint8, bool) {
    // it's cheaper to look up the struct in the mapping than to take it into memory
    //auctionInformation memory auction = auctionInfo[vaultAddress][life];
    uint256 startPrice = auctionInfo[vaultAddress][life].openDebt * auctionInfo[vaultAddress][life].liqThres / 100;
    uint256 surplusPrice = auctionInfo[vaultAddress][life].openDebt * (auctionInfo[vaultAddress][life].liqThres-100) / 100;
    uint256 priceDecrease = surplusPrice * (block.number - auctionInfo[vaultAddress][life].startBlock) / (hourlyBlocks * auctionDuration);

    uint256 totalPrice = startPrice - priceDecrease; 
    bool forSale = auctionInfo[vaultAddress][life].startBlock > 0 ? true : false;
    return (totalPrice, auctionInfo[vaultAddress][life].numeraire, forSale);
  }
    /** 
    @notice Function a user calls to buy the vault during the auction process. This ends the auction process
    @dev 
    @param vaultAddress the vaultAddress of the vault the user want to buy.
  */

  function buyVault(address vaultAddress, uint256 life) public {
    // it's 3683 gas cheaper to look up the struct 6x in the mapping than to take it into memory
    (uint256 priceOfVault,uint8 numeraire, bool forSale) = getPriceOfVault(vaultAddress, life);

    require(forSale, "LQ_BV: Not for sale");
    require(auctionInfo[vaultAddress][life].stablePaid < auctionInfo[vaultAddress][life].openDebt, "LQ_BV: Debt repaid");

    uint256 surplus = priceOfVault - auctionInfo[vaultAddress][life].openDebt;

    address stable = IFactory(factoryAddress).numeraireToStable(uint256(numeraire));
    require(IStable(stable).safeBurn(msg.sender, auctionInfo[vaultAddress][life].openDebt), "LQ_BV: Burn failed");
    require(IStable(stable).transferFrom(msg.sender, address(this), surplus), "LQ_BV: Surplus transfer failed");

    auctionInfo[vaultAddress][life].stablePaid = uint128(priceOfVault);
    
    IFactory(factoryAddress).safeTransferFrom(address(this), msg.sender, IFactory(factoryAddress).vaultIndex(vaultAddress));
  }

    /** 
    @notice Function a a user can call to check who is eligbile to claim what from an auction vault.
    @dev 
    @param auction the auction
    @param vaultAddress the vaultAddress of the vault the user want to buy.
    @param life the lifeIndex of vault, the keeper wants to claim their reward from
  */
  function claimable(auctionInformation memory auction, address vaultAddress, uint256 life) public view returns (uint256[] memory, address[] memory, uint8) {
    claimRatios memory ratios = claimRatio;
    uint256[] memory claimables = new uint256[](4);
    address[] memory claimableBy = new address[](4);
    uint256 claimableBitmapMem = claimableBitmap[vaultAddress][(life >> 6)];

    uint256 keeperReward = auction.openDebt * ratios.liquidationKeeper / 100;
    uint256 protocolReward = auction.openDebt * ratios.protocol / 100;
    uint256 reserveFundReward = auction.openDebt * ratios.reserveFund / 100;

    claimables[0] = claimableBitmapMem & (1 << 4*life + 0) == 0 ? keeperReward : 0;
    claimableBy[0] = auction.liquidationKeeper;

    if (auction.stablePaid < auction.openDebt || 
        auction.stablePaid <= keeperReward + auction.openDebt)
    {
      return (claimables, claimableBy, auction.numeraire);
    }

    uint256 leftover = auction.stablePaid - auction.openDebt - keeperReward;

    claimables[1] = claimableBitmapMem & (1 << 4*life + 1) == 0 ? (leftover >= reserveFundReward ? reserveFundReward : leftover) : 0;
    leftover = leftover >= reserveFundReward ? leftover - reserveFundReward : 0;

    claimables[2] = claimableBitmapMem & (1 << 4*life + 2) == 0 ? (leftover >= protocolReward ? protocolReward : leftover) : 0;
    leftover = leftover >= protocolReward ? leftover - protocolReward : 0;

    claimables[3] = claimableBitmapMem & (1 << 4*life + 3) == 0 ? leftover : 0;
    
    claimableBy[1] = reserveFund;
    claimableBy[2] = protocolTreasury;
    claimableBy[3] = auction.originalOwner;

    return (claimables, claimableBy, auction.numeraire);
  }

    /** 
    @notice Function a eligeble claimer can call to claim the proceeds of the vault they are entitled to.
    @dev 
    @param vaultAddresses vaultAddresses the caller want to claim the proceeds from.
    */
  function claimProceeds(address[] calldata vaultAddresses, uint256[] calldata lives) public {
    uint256 len = vaultAddresses.length;
    require(len == lives.length, "Arrays must be of same length");

    uint256[] memory totalClaimable;
    uint256 claimableBitmapMem;

    uint256[] memory claimables;
    address[] memory claimableBy;
    uint8 numeraire;
    for (uint256 i; i < len;) {
      address vaultAddress = vaultAddresses[i];
      uint256 life = lives[i];
      auctionInformation memory auction = auctionInfo[vaultAddress][life];
      (claimables, claimableBy, numeraire) = claimable(auction, vaultAddress, life);
      claimableBitmapMem = claimableBitmap[vaultAddress][(life >> 6)];

      if (msg.sender == claimableBy[0]) {
        totalClaimable[numeraire] += claimables[0];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 0));
      }
      if (msg.sender == claimableBy[1]) {
        totalClaimable[numeraire] += claimables[1];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 1));
      }
      if (msg.sender == claimableBy[2]) {
        totalClaimable[numeraire] += claimables[2];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 2));
      }
      if (msg.sender == claimableBy[3]) {
        totalClaimable[numeraire] += claimables[3];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 3));
      }

      claimableBitmap[vaultAddress][(life >> 6)] = claimableBitmapMem;

      unchecked {++i;}
    }

    for (uint8 k; k < totalClaimable.length;) {
      require(IStable(IFactory(factoryAddress).numeraireToStable(k)).transferFrom(address(this), msg.sender, totalClaimable[k]));
      unchecked {++k;}
    }
  }

  //function buy(assets, amounts, ids) payable
  //  fetches price of first provided
  //  if buy-price is >= open debt, close auction & take fees (how?)
  //  (if all assets are bought, transfer vault)
  //  (for purchase that ends auction, give discount?)


}
