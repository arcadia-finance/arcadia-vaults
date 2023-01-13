/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./interfaces/IFactory.sol";
import "./interfaces/IMainRegistry.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVault.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/ILendingPool.sol";

/**
 * @title The liquidator holds the execution logic and storage or all things related to liquidating Arcadia Vaults
 * @author Arcadia Finance
 * @notice Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev contact: dev at arcadia.finance
 */
contract Liquidator is Ownable {
    uint256 public constant hourlyBlocks = 300;
    uint256 public breakevenTime = 6; //hours

    address public factory;
    address public registry;
    address public reserveFund;
    address public protocolTreasury;

    mapping(address => auctionInformation) public auctionInfo;
    mapping(address => mapping(uint256 => uint256)) public claimableBitmap;

    mapping(address => mapping(address => uint256)) public openClaims;

    claimRatios public claimRatio;

    /**
     * @notice The ratios in which the liquidation fee is divided
     * @dev ratio's have 2 decimals precision (50 equals 0,5 or 50%)
     */
    struct claimRatios {
        uint64 protocol;
        uint64 liquidationInitiator;
    }

    struct auctionInformation {
        uint128 openDebt;
        uint128 startBlock;
        uint128 assetPaid;
        bool stopped;
        address baseCurrency;
        address originalOwner;
        address trustedCreditor;
    }

    modifier elevated() {
        require(IFactory(factory).isVault(msg.sender), "LQ: Not a vault!");
        _;
    }

    constructor(address factory_, address registry_) {
        factory = factory_;
        registry = registry_;
        claimRatio = claimRatios({protocol: 5, liquidationInitiator: 2});
    }

    /*///////////////////////////////////////////////////////////////
                          EXTERNAL CONTRACTS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the factory address on the liquidator.
     * @dev The factory is used to fetch the isVault bool in elevated().
     * @param factory_ the factory address.
     */
    function setFactory(address factory_) external onlyOwner {
        factory = factory_;
    }

    /**
     * @notice Sets the protocol treasury address on the liquidator.
     * @dev The protocol treasury is used to receive liquidation rewards.
     * @param protocolTreasury_ the protocol treasury.
     */
    function setProtocolTreasury(address protocolTreasury_) external onlyOwner {
        protocolTreasury = protocolTreasury_;
    }

    /**
     * @notice Sets the reserve fund address on the liquidator.
     * @dev The reserve fund is used to pay liquidation keepers should the liquidation surplus be insufficient.
     * @param reserveFund_ the reserve fund address.
     */
    function setReserveFund(address reserveFund_) external onlyOwner {
        reserveFund = reserveFund_;
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the breakeven time on the liquidator.
     * @dev The breakeven time is the time from starting an auction duration to
     * the moment the price of the auction has decreased to the open debt.
     * The breakevenTime controls the speed of decrease of the auction price.
     * @param breakevenTime_ the new breakeven time address.
     */
    function setBreakevenTime(uint256 breakevenTime_) external onlyOwner {
        breakevenTime = breakevenTime_;
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Starts an auction of a vault. Called by the vault itself.
     * @param liquidationInitiator the keeper who triggered the auction. Gets a reward!
     * @param originalOwner the original owner of this vault, at `life`.
     * @param openDebt the open debt taken by `originalOwner` at `life`.
     * @param baseCurrency the baseCurrency in which the vault is denominated.
     * @param trustedCreditor The account or contract that is owed the debt.
     * @return success auction has started -> true.
     */
    function startAuction(
        address liquidationInitiator,
        address originalOwner,
        uint128 openDebt,
        address baseCurrency,
        address trustedCreditor
    ) public elevated returns (bool success) {
        require(auctionInfo[msg.sender].startBlock == 0, "Liquidation already ongoing");

        auctionInfo[msg.sender].startBlock = uint128(block.number);
        auctionInfo[msg.sender].originalOwner = originalOwner;
        auctionInfo[msg.sender].openDebt = openDebt;
        auctionInfo[msg.sender].baseCurrency = baseCurrency;
        auctionInfo[msg.sender].trustedCreditor = trustedCreditor;

        openClaims[liquidationInitiator][baseCurrency] += calcLiquidationInitiatorReward(openDebt);

        success = true;
    }

    function calcLiquidationInitiatorReward(uint128 openDebt) public view returns (uint256 keeperReward) {
        //Calculate liquidationInitiator as the minimum between a percentage of a position capped by a certain amount
        //ToDo: How are we going to cap the max?
        keeperReward = openDebt * claimRatio.liquidationInitiator / 100;
    }

    /**
     * @notice Function to check what the current price of the vault being auctioned of is.
     * @dev Returns whether the vault is on sale or not. Always check the forSale bool!
     * @param vaultAddress the vaultAddress.
     * @return totalPrice the total price for which the vault can be purchased.
     * @return baseCurrency the baseCurrency in which the vault (and totalPrice) is denominaetd.
     * @return forSale returns false when the vault is not for sale.
     */
    function getPriceOfVault(address vaultAddress)
        public
        view
        returns (uint256 totalPrice, address baseCurrency, bool forSale)
    {
        forSale = !(auctionInfo[vaultAddress].stopped) && auctionInfo[vaultAddress].startBlock > 0;

        if (!forSale) {
            return (0, address(0), false);
        }

        uint256 startPrice = (auctionInfo[vaultAddress].openDebt * 150) / 100;
        uint256 surplusPrice = (auctionInfo[vaultAddress].openDebt * (150 - 100)) / 100;
        uint256 priceDecrease =
            (surplusPrice * (block.number - auctionInfo[vaultAddress].startBlock)) / (hourlyBlocks * breakevenTime);

        totalPrice;
        if (priceDecrease > startPrice) {
            //ヽ༼ຈʖ̯ຈ༽ﾉ
            totalPrice = 0;
        } else {
            totalPrice = startPrice - priceDecrease;
        }

        return (totalPrice, auctionInfo[vaultAddress].baseCurrency, forSale);
    }

    /**
     * @notice Function a user calls to buy the vault during the auction process. This ends the auction process
     * @dev Ensure the vault is for sale before calling this function.
     * @param vaultAddress the vaultAddress of the vault the user want to buy.
     */
    function buyVault(address vaultAddress) public {
        (uint256 priceOfVault,, bool forSale) = getPriceOfVault(vaultAddress);

        require(forSale, "LQ_BV: Not for sale");

        address trustedCreditor = auctionInfo[vaultAddress].trustedCreditor;
        address asset = auctionInfo[vaultAddress].baseCurrency;

        require(IERC20(asset).transferFrom(msg.sender, address(this), priceOfVault), "LQ_BV: transfer failed");

        uint256 openDebt = auctionInfo[vaultAddress].openDebt;
        claimRatios memory ratios = claimRatio;
        uint256 keeperReward = openDebt * ratios.liquidationInitiator / 100;

        if (priceOfVault < openDebt + keeperReward) {
            uint256 default_ = openDebt + keeperReward - priceOfVault;
            uint256 deficit = priceOfVault < keeperReward ? keeperReward - openDebt : 0;
            if (deficit == 0) {
                IERC20(asset).transfer(trustedCreditor, openDebt - default_);
            } //ToDo do one transfer from msg.sender directly to liquiditypool?
            ILendingPool(trustedCreditor).settleLiquidation(default_, deficit);
        } else {
            IERC20(asset).transfer(trustedCreditor, openDebt);
            //ToDo: transfer protocolReward to Liquidity Pool
            //uint256 protocolReward = openDebt * ratios.protocol / 100;
            //uint256 surplus = priceOfVault - auctionInfo[vaultAddress][life].openDebt;
            //protocolReward = surplus > protocolReward ? protocolReward  : surplus;
        }

        auctionInfo[vaultAddress].assetPaid = uint128(priceOfVault);
        auctionInfo[vaultAddress].stopped = true;
        //ToDo: set all auction information to 0?

        IFactory(factory).safeTransferFrom(address(this), msg.sender, IFactory(factory).vaultIndex(vaultAddress));
    }

    /*///////////////////////////////////////////////////////////////
                MANAGE AND PAY OUT AUCTION PROCEEDS
    ///////////////////////////////////////////////////////////////*/

    function claim(address baseCurrency, uint256 amount) public {
        //Will revert if msg.sender want to claim more than their open claims
        openClaims[msg.sender][baseCurrency] -= amount;
        IERC20(baseCurrency).transfer(msg.sender, amount);
    }

    /**
     * @notice Function a a user can call to check who is eligbile to claim what from an auction vault.
     * @dev Although only 3 bits are needed per claim in claimableBitmap, we keep it per 4.
     * This saves some gas on calculations, and would only require writing a new
     * bitmap after 65 liquidations instead of 85. We're looking forward to the first
     * vault that gets liquidated 65 times!
     * @param auction the auction
     * @param vaultAddress the vaultAddress of the vault the user want to buy.
     * @param life the lifeIndex of vault, the keeper wants to claim their reward from
     * @return claimables The amounts claimable for a certain auction (in the baseCurrency of the vault).
     * @return claimableBy The user that can claim the liquidation reward or surplus.
     */
    function claimable(auctionInformation memory auction, address vaultAddress, uint256 life)
        public
        view
        returns (uint256[] memory claimables, address[] memory claimableBy)
    {
        claimRatios memory ratios = claimRatio;
        claimables = new uint256[](3);
        claimableBy = new address[](3);
        uint256 claimableBitmapMem = claimableBitmap[vaultAddress][(life >> 6)];

        uint256 keeperReward = (auction.openDebt * ratios.liquidationInitiator) / 100;
        uint256 protocolReward = (auction.openDebt * ratios.protocol) / 100;

        claimables[0] = claimableBitmapMem & (1 << (4 * life + 0)) == 0 ? keeperReward : 0;

        if (auction.assetPaid < auction.openDebt || auction.assetPaid <= keeperReward + auction.openDebt) {
            return (claimables, claimableBy);
        }

        uint256 leftover = auction.assetPaid - auction.openDebt - keeperReward;

        claimables[1] = claimableBitmapMem & (1 << (4 * life + 1)) == 0
            ? (leftover >= protocolReward ? protocolReward : leftover)
            : 0;
        leftover = leftover >= protocolReward ? leftover - protocolReward : 0;

        claimables[2] = claimableBitmapMem & (1 << (4 * life + 2)) == 0 ? leftover : 0;

        claimableBy[1] = protocolTreasury;
        claimableBy[2] = auction.originalOwner;
    }

    // /**
    //  * @notice Function a eligeble claimer can call to claim the proceeds of the vault they are entitled to.
    //  * @dev vaultAddresses and lives form a combination. Claiming for combinations at vaultAddress[i] && lives[i]
    //  * if multiple lives of the same vault address are to be claimed, the vault address must be repeated!
    //  * Although only 3 bits are needed per claim in claimableBitmap, we keep it per 4.
    //  * This saves some gas on calculations, and would only require writing a new
    //  * bitmap after 65 liquidations instead of 85. We're looking forward to the first
    //  * vault that gets liquidated 65 times!
    //  * @param claimer the address for which (and to which) the claims are requested.
    //  * @param vaultAddresses vault addresses the caller want to claim the proceeds from.
    //  * @param lives the lives for which the caller wants to claim for.
    //  * //todo: make view function showing available addresses & lives for a claimer
    //  */
    // function claimProceeds(address claimer, address[] calldata vaultAddresses, uint256[] calldata lives) public {
    //     uint256 len = vaultAddresses.length;
    //     require(len == lives.length, "Arrays must be of same length");
    //     uint256 baseCurrencyCounter = IMainRegistry(registry).baseCurrencyCounter();

    //     uint256[] memory totalClaimable = new uint256[](baseCurrencyCounter);
    //     uint256 claimableBitmapMem;

    //     uint256[] memory claimables;
    //     address[] memory claimableBy;
    //     for (uint256 i; i < len;) {
    //         address vaultAddress = vaultAddresses[i];
    //         uint256 life = lives[i];
    //         auctionInformation memory auction = auctionInfo[vaultAddress][life];
    //         (claimables, claimableBy) = claimable(auction, vaultAddress, life);
    //         claimableBitmapMem = claimableBitmap[vaultAddress][(life >> 6)];

    //         if (claimer == claimableBy[0]) {
    //             totalClaimable[auction.baseCurrency] += claimables[0];
    //             claimableBitmapMem = claimableBitmapMem | (1 << (4 * life + 0));
    //         }
    //         if (claimer == claimableBy[1]) {
    //             totalClaimable[auction.baseCurrency] += claimables[1];
    //             claimableBitmapMem = claimableBitmapMem | (1 << (4 * life + 1));
    //         }
    //         if (claimer == claimableBy[2]) {
    //             totalClaimable[auction.baseCurrency] += claimables[2];
    //             claimableBitmapMem = claimableBitmapMem | (1 << (4 * life + 2));
    //         }

    //         claimableBitmap[vaultAddress][(life >> 6)] = claimableBitmapMem;

    //         unchecked {
    //             ++i;
    //         }
    //     }

    //     _doTransfers(baseCurrencyCounter, totalClaimable, claimer);
    // }

    function _doTransfers(uint256 baseCurrencyCounter, uint256[] memory totalClaimable, address claimer) internal {
        for (uint8 k; k < baseCurrencyCounter;) {
            if (totalClaimable[k] > 0) {
                address asset = IMainRegistry(registry).baseCurrencies(uint256(k));
                require(IERC20(asset).transfer(claimer, totalClaimable[k]));
            }
            unchecked {
                ++k;
            }
        }
    }
}
