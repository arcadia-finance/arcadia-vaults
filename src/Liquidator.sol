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

    mapping(address => AuctionInformation) public auctionInformation;
    mapping(address => mapping(address => uint256)) public openClaims;

    ClaimRatios public claimRatios;

    /**
     * @notice The ratios in which the liquidation fee is divided
     * @dev ratio's have 2 decimals precision (50 equals 0,5 or 50%)
     */
    struct ClaimRatios {
        uint64 protocol;
        uint64 liquidationInitiator;
    }

    struct AuctionInformation {
        uint128 openDebt;
        uint128 startBlock;
        bool inAuction;
        address baseCurrency;
        address originalOwner;
        address trustedCreditor;
    }

    constructor(address factory_, address registry_) {
        factory = factory_;
        registry = registry_;
        claimRatios = ClaimRatios({protocol: 5, liquidationInitiator: 2});
    }

    /*///////////////////////////////////////////////////////////////
                          EXTERNAL CONTRACTS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the factory address on the liquidator.
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
     * @param originalOwner the original owner of this vault.
     * @param openDebt the open debt taken by `originalOwner` at moment of liquidation.
     * @param baseCurrency the baseCurrency in which the vault is denominated.
     * @param trustedCreditor The account or contract that is owed the debt.
     */
    function startAuction(
        address liquidationInitiator,
        address originalOwner,
        uint128 openDebt,
        address baseCurrency,
        address trustedCreditor
    ) public {
        require(IFactory(factory).isVault(msg.sender), "LQ_SA: Not a vault");
        require(!auctionInformation[msg.sender].inAuction, "LQ_SA: Auction already ongoing");

        auctionInformation[msg.sender].inAuction = true;
        auctionInformation[msg.sender].startBlock = uint128(block.number);
        auctionInformation[msg.sender].originalOwner = originalOwner;
        auctionInformation[msg.sender].openDebt = openDebt;
        auctionInformation[msg.sender].baseCurrency = baseCurrency;
        auctionInformation[msg.sender].trustedCreditor = trustedCreditor;

        //Initiator can immediately claim the initiator reward.
        //In edge cases, there might not be sufficient funds on the LiquidationEngine contract,
        //and the initiator will have to wait until the auction of collateral is finished.
        openClaims[liquidationInitiator][baseCurrency] += calcLiquidationInitiatorReward(openDebt);
    }

    /**
     * @notice Calculates the Reward in baseCurrency for the Liquidation Initiator.
     * @param openDebt the open debt taken by `originalOwner`.
     * @return liquidationInitiatorReward The Reward in baseCurrency for the Liquidation Initiator.
     */
    function calcLiquidationInitiatorReward(uint256 openDebt)
        public
        view
        returns (uint256 liquidationInitiatorReward)
    {
        //Calculate liquidationInitiator as the minimum between a percentage of a position capped by a certain amount
        //ToDo: How are we going to cap the max?
        liquidationInitiatorReward = openDebt * claimRatios.liquidationInitiator / 100;
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
        forSale = auctionInformation[vaultAddress].inAuction && auctionInformation[vaultAddress].startBlock > 0;

        if (!forSale) {
            return (0, address(0), false);
        }

        uint256 startPrice = (auctionInformation[vaultAddress].openDebt * 150) / 100;
        uint256 surplusPrice = (auctionInformation[vaultAddress].openDebt * (150 - 100)) / 100;
        uint256 priceDecrease = (surplusPrice * (block.number - auctionInformation[vaultAddress].startBlock))
            / (hourlyBlocks * breakevenTime);

        totalPrice;
        if (priceDecrease > startPrice) {
            //ヽ༼ຈʖ̯ຈ༽ﾉ
            totalPrice = 0;
        } else {
            totalPrice = startPrice - priceDecrease;
        }

        return (totalPrice, auctionInformation[vaultAddress].baseCurrency, forSale);
    }

    /**
     * @notice Function a user calls to buy the vault during the auction process. This ends the auction process
     * @dev Ensure the vault is for sale before calling this function.
     * @param vaultAddress the vaultAddress of the vault the user want to buy.
     */
    function buyVault(address vaultAddress) public {
        (uint256 priceOfVault,, bool forSale) = getPriceOfVault(vaultAddress);

        require(forSale, "LQ_BV: Not for sale");

        address trustedCreditor = auctionInformation[vaultAddress].trustedCreditor;
        address asset = auctionInformation[vaultAddress].baseCurrency;

        require(IERC20(asset).transferFrom(msg.sender, address(this), priceOfVault), "LQ_BV: transfer failed");

        uint256 openDebt = auctionInformation[vaultAddress].openDebt;
        ClaimRatios memory ratios = claimRatios;
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
            //uint256 surplus = priceOfVault - auctionInformation[vaultAddress][life].openDebt;
            //protocolReward = surplus > protocolReward ? protocolReward  : surplus;
        }

        auctionInformation[vaultAddress].inAuction = false;
        //ToDo: set all auction information to 0?

        IFactory(factory).safeTransferFrom(address(this), msg.sender, IFactory(factory).vaultIndex(vaultAddress));
    }

    /*///////////////////////////////////////////////////////////////
                    CLAIM AUCTION PROCEEDS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim auction proceeds.
     * @param baseCurrency The address of the claimable asset, an ERC20 token.
     * @param amount The amount of tokens claimed.
     */
    function claim(address baseCurrency, uint256 amount) public {
        //Will revert if msg.sender wants to claim more than their open claims
        openClaims[msg.sender][baseCurrency] -= amount;
        IERC20(baseCurrency).transfer(msg.sender, amount);
    }
}
