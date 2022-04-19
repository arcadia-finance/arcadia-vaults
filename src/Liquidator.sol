// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IFactory.sol";

import "./interfaces/IMainRegistry.sol";

import "./interfaces/IStable.sol";

import "./interfaces/IVault.sol";


contract Liquidator {

  address public factoryAddress;
  address public owner;
  uint8 public numeraireOfDebt;
  address public registryAddress;
  address public stable;
  address public reserveFund;

  uint256 constant public hourlyBlocks = 300;
  uint256 public auctionDuration = 6; //hours

  claimRatios public claimRatio;

  struct claimRatios {
    uint64 protocol;
    uint64 originalOwner;
    uint64 liquidator;
    uint64 reserveFund;
  }

  struct auctionInformation {
    uint128 openDebt;
    uint128 startBlock;
    uint8 liqThres;
    uint128 stablePaid;
    address liquidator;
    address originalOwner;
  }

  mapping (address => mapping (uint256 => auctionInformation)) public auctionInfo;
  mapping (address => uint256) public claimableBitmap;

  constructor(address newFactory, address newRegAddr, address stableAddr) {
    factoryAddress = newFactory;
    owner = msg.sender;
    numeraireOfDebt = 0;
    registryAddress = newRegAddr;
    stable = stableAddr;
    claimRatio = claimRatios({protocol: 20, originalOwner: 60, liquidator: 10, reserveFund: 10});
  }

  modifier elevated() {
    require(IFactory(factoryAddress).isVault(msg.sender), "This can only be called by a vault");
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner");
    _;
  }

  function setFactory(address newFactory) external onlyOwner {
    factoryAddress = newFactory;
  }

  //function startAuction() modifier = only by vault
  //  sets time start to now()
  //  stores the liquidator
  // 

  function startAuction(address vaultAddress, uint256 life, address liquidator, address originalOwner, uint128 openDebt, uint8 liqThres) public elevated returns (bool) {

    require(auctionInfo[vaultAddress][life].startBlock == 0, "Liquidation already ongoing");

    auctionInfo[vaultAddress][life].startBlock = uint128(block.number);
    auctionInfo[vaultAddress][life].liquidator = liquidator;
    auctionInfo[vaultAddress][life].originalOwner = originalOwner;
    auctionInfo[vaultAddress][life].openDebt = openDebt;
    auctionInfo[vaultAddress][life].liqThres = liqThres;

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
  function getPriceOfAssets(address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) public view returns (uint256) {
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
  function getPriceOfVault(address vaultAddress, uint256 life) public view returns (uint256, bool) {
    // it's cheaper to look up the struct in the mapping than to take it into memory
    //auctionInformation memory auction = auctionInfo[vaultAddress][life];
    uint256 startPrice = auctionInfo[vaultAddress][life].openDebt * auctionInfo[vaultAddress][life].liqThres / 100;
    uint256 surplusPrice = auctionInfo[vaultAddress][life].openDebt * (auctionInfo[vaultAddress][life].liqThres-100) / 100;
    uint256 priceDecrease = surplusPrice * (block.number - auctionInfo[vaultAddress][life].startBlock) / (hourlyBlocks * auctionDuration);

    if (startPrice < priceDecrease) {
      return (0, false);
    }

    uint256 totalPrice = startPrice - priceDecrease; 
    bool forSale = block.number - auctionInfo[vaultAddress][life].startBlock <= hourlyBlocks * auctionDuration ? true : false;
    return (totalPrice, forSale);
  }
    /** 
    @notice Function a user calls to buy the vault during the auction process. This ends the auction process
    @dev 
    @param vaultAddress the vaultAddress of the vault the user want to buy.
  */

  function buyVault(address vaultAddress, uint256 life) public {
    // it's 3683 gas cheaper to look up the struct 6x in the mapping than to take it into memory
    (uint256 priceOfVault, bool forSale) = getPriceOfVault(vaultAddress, life);

    require(forSale, "Too much time has passed: this vault is not for sale");
    require(auctionInfo[vaultAddress][life].stablePaid < auctionInfo[vaultAddress][life].openDebt, "This vaults debt has already been paid in full!");

    uint256 surplus = priceOfVault - auctionInfo[vaultAddress][life].openDebt;

    require(IStable(stable).safeBurn(msg.sender, auctionInfo[vaultAddress][life].openDebt), "Cannot burn sufficient stable debt");
    require(IStable(stable).transferFrom(msg.sender, address(this), surplus), "Surplus transfer failed");

    auctionInfo[vaultAddress][life].stablePaid = uint128(priceOfVault);
    
    //TODO: fetch vault id.
    IFactory(factoryAddress).safeTransferFrom(address(this), msg.sender, IFactory(factoryAddress).vaultIndex(vaultAddress));
  }
    /** 
    @notice Function a a user can call to check who is eligbile to claim what from an auction vault.
    @dev 
    @param auction the auction
    @param vaultAddress the vaultAddress of the vault the user want to buy.
    @param life the lifeIndex of vault, the keeper wants to claim their reward from
  */
  function claimable(auctionInformation memory auction, address vaultAddress, uint256 life) public view returns (uint256[] memory, address[] memory) {
    claimRatios memory ratios = claimRatio;
    uint256[] memory claimables = new uint256[](4);
    address[] memory claimableBy = new address[](4);
    uint256 claimableBitmapMem = claimableBitmap[vaultAddress];

    uint256 surplus = auction.stablePaid - auction.openDebt;

    claimables[0] = claimableBitmapMem & (1 << 4*life + 0) == 0 ? surplus * ratios.protocol / 100: 0;
    claimables[1] = claimableBitmapMem & (1 << 4*life + 1) == 0 ? surplus * ratios.originalOwner / 100: 0;
    claimables[2] = claimableBitmapMem & (1 << 4*life + 2) == 0 ? surplus * ratios.liquidator / 100: 0;
    claimables[3] = claimableBitmapMem & (1 << 4*life + 3) == 0 ? surplus * ratios.reserveFund / 100: 0;

    claimableBy[0] = address(this);
    claimableBy[1] = auction.originalOwner;
    claimableBy[2] = auction.liquidator;
    claimableBy[3] = reserveFund;

    return (claimables, claimableBy);
  }
    /** 
    @notice Function a eligeble claimer can call to claim the proceeds of the vault they are entitled to.
    @dev 
    @param vaultAddresses vaultAddresses the caller want to claim the proceeds from.
    */
  function claimProceeds(address[] calldata vaultAddresses, uint256[] calldata lives) public {
    uint256 len = vaultAddresses.length;
    require(len == lives.length, "Arrays must be of same length");

    uint256 totalClaimable;
    uint256 claimableBitmapMem;

    uint256[] memory claimables;
    address[] memory claimableBy;
    for (uint256 i; i < len;) {
      address vaultAddress = vaultAddresses[i];
      uint256 life = lives[i];
      auctionInformation memory auction = auctionInfo[vaultAddress][life];
      (claimables, claimableBy) = claimable(auction, vaultAddress, life);
      claimableBitmapMem = claimableBitmap[vaultAddress];

      if (msg.sender == claimableBy[0]) {
        totalClaimable += claimables[0];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 0));
      }
      if (msg.sender == claimableBy[1]) {
        totalClaimable += claimables[1];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 1));
      }
      if (msg.sender == claimableBy[2]) {
        totalClaimable += claimables[2];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 2));
      }
      if (msg.sender == claimableBy[3]) {
        totalClaimable += claimables[3];
        claimableBitmapMem = claimableBitmapMem | (1 << (4*life + 3));
      }

      claimableBitmap[vaultAddress] = claimableBitmapMem;

      unchecked {++i;}
    }

    require(IStable(stable).transferFrom(address(this), msg.sender, totalClaimable));
  }

  //function buy(assets, amounts, ids) payable
  //  fetches price of first provided
  //  if buy-price is >= open debt, close auction & take fees (how?)
  //  (if all assets are bought, transfer vault)
  //  (for purchase that ends auction, give discount?)


}
