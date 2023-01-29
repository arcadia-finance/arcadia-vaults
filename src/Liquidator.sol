/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {LogExpMath} from "./utils/LogExpMath.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";

/**
 * @title The liquidator holds the execution logic and storage or all things related to liquidating Arcadia Vaults
 * @author Arcadia Finance
 * @notice Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev contact: dev at arcadia.finance
 */
contract Liquidator is Ownable {
    uint16 public startPriceMultiplier; // 2 decimals
    // @dev 18 decimals
    // It is the discount for an auction, per second passed after the auction.
    // example: 999807477651317500, it is calculated based on the half-life of 1 hour
    uint64 public discountRate;
    uint16 public auctionCutoffTime; // maximum auction time in seconds that auction can run from the start of auction, max 18 hours

    address public factory;
    address public registry;

    mapping(address => AuctionInformation) public auctionInformation;
    mapping(address => mapping(address => uint256)) public openClaims;

    ClaimRatios public claimRatios;

    /**
     * @notice The ratios in which the liquidation fee is divided
     * @dev ratio's have 2 decimals precision (50 equals 0,5 or 50%)
     */
    struct ClaimRatios {
        uint64 penalty;
        uint64 initiatorReward;
    }

    struct AuctionInformation {
        uint128 openDebt;
        uint128 startTime;
        bool inAuction;
        address baseCurrency;
        address originalOwner;
        address trustedCreditor;
    }

    constructor(address factory_, address registry_) {
        factory = factory_;
        registry = registry_;
        claimRatios = ClaimRatios({penalty: 5, initiatorReward: 2});
        startPriceMultiplier = 110;
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

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the Claim Ratios.
     * @param claimRatios_ The new Claim ratios.
     * @dev Each claim ratio has 2 decimals precision (50 equals 0,5 or 50%)
     */
    function setClaimRatios(ClaimRatios memory claimRatios_) external onlyOwner {
        //ToDo: set upper bounds?
        claimRatios = claimRatios_;
    }

    /**
     * @notice Sets the discount rate (DR) for the liquidator.
     * @param halfLife The new half life time (T_hl), in seconds.
     * @dev The discount rate is a multiplier that is used to decrease the price of the auction over time.
     * @dev Exponential decay is defined as: P(t) = P(0) * (1/2)^(t/T_hl)
     * Or simplified: P(t) = P(O) * DR^t with DR = 1/[2^(1/T_hl)]
     */
    function setDiscountRate(uint256 halfLife) external onlyOwner {
        require(halfLife > 30 * 60, "LQ_DR: halfLife too low"); // 30 minutes
        require(halfLife < 8 * 60 * 60, "LQ_DR: halfLife too high"); // 8 hours
        //Both the base and exponent of LogExpMath.pow have 18 decimals, and its result has 18 decimals as well.
        //Since discountRate itself has 18 decimals and it is divided by a number with 18 decimals,
        //we need to multiply with another 10e18.
        discountRate = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLife)));
    }

    /**
     * @notice Sets the max cutoff time for the liquidator.
     * @param auctionCutoffTime_ The new max cutoff time. It is seconds that auction can run from the start of auction.
     * @dev The max cutoff time is the maximum time an auction can run.
     * Setting a very short auctionCutoffTime can be used by rogue owners to rug the junior tranche!!
     * Therefore the auctionCutoffTime has hardcoded constraints.
     */
    function setAuctionCutoffTime(uint16 auctionCutoffTime_) external onlyOwner {
        require(auctionCutoffTime_ > 1 * 60 * 60, "LQ_ACT: cutoff too low"); // 1 hour
        require(auctionCutoffTime_ < 8 * 60 * 60, "LQ_ACT: cutoff too high"); // 8 hours
        auctionCutoffTime = auctionCutoffTime_;
    }

    /**
     * @notice Sets the start price multiplier for the liquidator.
     * @param startPriceMultiplier_ The new start price multiplier, with 2 decimals precision.
     * @dev The start price multiplier is a multiplier that is used to increase the initial price of the auction.
     * Since the value of all assets is dicounted with the liquidation factor, and because pricing modules will take a conservative
     * approach to price assets (eg. floorprices for NFTs), the actual value of the assets being auctioned might be substantially higher
     * as the open debt. Hence the auction starts at a multiplier of the opendebt, but decreases rapidly (exponential decay).
     */
    function setStartPriceMultiplier(uint16 startPriceMultiplier_) external onlyOwner {
        require(startPriceMultiplier_ > 100, "LQ_SPM: multiplier too low");
        require(startPriceMultiplier_ < 301, "LQ_SPM: multiplier too high");
        startPriceMultiplier = startPriceMultiplier_;
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Called by a Creditor to start an auction to liquidate collateral of a vault.
     * @param vault The contract address of the Vault to liquidate.
     * @param openDebt The open debt taken by `originalOwner`.
     * @dev This function is called by the Creditor who is owed the debt against the Vault.
     */
    function startAuction(address vault, uint256 openDebt) public {
        require(!auctionInformation[vault].inAuction, "LQ_SA: Auction already ongoing");
        require(IFactory(factory).isVault(vault), "LQ_SA: Not a vault");

        (address originalOwner, address baseCurrency, address trustedCreditor) = IVault(vault).liquidateVault(openDebt);

        //Check that msg.sender is indeed the Creditor of the Vault
        require(trustedCreditor == msg.sender, "LQ_SA: Unauthorised");

        auctionInformation[vault].inAuction = true;
        auctionInformation[vault].startTime = uint128(block.timestamp);
        auctionInformation[vault].originalOwner = originalOwner;
        auctionInformation[vault].openDebt = uint128(openDebt);
        auctionInformation[vault].baseCurrency = baseCurrency;
        auctionInformation[vault].trustedCreditor = trustedCreditor;
    }

    /**
     * @notice Function returns the current auction price of a vault.
     * @param vault The contract address of the vault.
     * @return price the total price for which the vault can be purchased.
     * @return inAuction returns false when the vault is not being auctioned.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function getPriceOfVault(address vault) public view returns (uint256 price, bool inAuction) {
        inAuction = auctionInformation[vault].inAuction;

        if (!inAuction) {
            return (0, false);
        }

        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInformation[vault].startTime;
        }
        if (timePassed > auctionCutoffTime) {
            return (0, false);
        }

        price = _calcPriceOfVault(timePassed, auctionInformation[vault].openDebt);
    }

    /**
     * @notice Function returns the current auction price given time passed and the openDebt.
     * @param timePassed delta between current time and auction start time.
     * @param openDebt The open debt taken by `originalOwner`.
     * @return price The total price for which the vault can be purchased.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     * @dev Price decreases exponentially: P(t) = P(O) * DR^t with P(O) = openDebt * startPriceMultiplier.
     */
    function _calcPriceOfVault(uint256 timePassed, uint256 openDebt) internal view returns (uint256 price) {
        uint256 auctionTime;
        unchecked {
            auctionTime = timePassed * 1e18;
        }
        //startPriceMultiplier has 2 decimals precision and LogExpMath.pow() has 18 decimals precision,
        //hence we need to divide the result by 1e20.
        price = openDebt * startPriceMultiplier * LogExpMath.pow(discountRate, auctionTime) / 1e20;
    }

    /**
     * @notice Function a user (the bidder) calls to buy the vault and end the auction.
     * @param vault The contract address of the vault.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function buyVault(address vault) external {
        AuctionInformation memory auctionInformation_ = auctionInformation[vault];
        require(auctionInformation_.inAuction, "LQ_BV: Not for sale");

        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInformation_.startTime;
        }

        uint256 priceOfVault = _calcPriceOfVault(timePassed, auctionInformation_.openDebt);
        //Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[vault].inAuction = false;

        //Transfer funds, equal to the current auction price from the bidder to the Creditor contract.
        //The bidder should have approved the Liquidation contract for at least an amount of priceOfVault.
        require(
            IERC20(auctionInformation_.baseCurrency).transferFrom(
                msg.sender, auctionInformation_.trustedCreditor, priceOfVault
            ),
            "LQ_BV: transfer from failed"
        );

        (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder) =
            calcLiquidationSettlementValues(auctionInformation_.openDebt, priceOfVault);

        ILendingPool(auctionInformation_.trustedCreditor).settleLiquidation(
            vault, auctionInformation_.originalOwner, badDebt, liquidationInitiatorReward, liquidationPenalty, remainder
        );

        //Change ownership of the auctioned vault to the bidder.
        IFactory(factory).safeTransferFrom(address(this), msg.sender, vault);
    }

    /**
     * @notice End an unsuccessful auction after the auctionCutoffTime has passed.
     * @param vault The contract address of the vault.
     * @param to The address to which the vault will be transferred.
     * @dev The auction will be stopped and the vault will be transferred to the provided address.
     * The junior tranche of the liquidity pool will pay for the bad debt. 
     * The protocol will sell/auction the vault in another way to recover the debt.
     * The protocol can then "donate" these proceeds to the junior tranche.
     */
    function endAuction(address vault, address to) external onlyOwner {
        AuctionInformation memory auctionInformation_ = auctionInformation[vault];
        require(auctionInformation_.inAuction, "LQ_EA: Not for sale");

        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInformation_.startTime;
        }
        require(timePassed > auctionCutoffTime, "LQ_EA: Auction not expired");

        //Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[vault].inAuction = false;

        (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder) =
            calcLiquidationSettlementValues(auctionInformation_.openDebt, 0); //price is zero

        ILendingPool(auctionInformation_.trustedCreditor).settleLiquidation(
            vault, auctionInformation_.originalOwner, badDebt, liquidationInitiatorReward, liquidationPenalty, remainder
        );

        //Change ownership of the auctioned vault to the protocol owner.
        IFactory(factory).safeTransferFrom(address(this), to, vault);
    }

    /**
     * @notice Calculates how the liquidation needs to be further settled with the Creditor, Original owner and Service providers.
     * @param openDebt The open debt taken by `originalOwner`.
     * @param priceOfVault The final selling price of the Vault.
     * @return badDebt The amount of liabilities that was not recouped by the auction.
     * @return liquidationInitiatorReward The Reward for the Liquidation Initiator.
     * @return liquidationPenalty The additional penalty the `originalOwner` has to pay to the protocol.
     * @return remainder Any funds remaining after the auction are returned back to the `originalOwner`.
     * @dev All values are denominated in the baseCurrency of the Vault
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function calcLiquidationSettlementValues(uint256 openDebt, uint256 priceOfVault)
        public
        view
        returns (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder)
    {
        ClaimRatios memory claimRatios_ = claimRatios;

        //openDebt is a uint128 -> all calculations can be unchecked
        unchecked {
            //Liquidation Initiator Reward is always paid out, independent of the final auction price
            liquidationInitiatorReward = openDebt * claimRatios_.initiatorReward / 100;

            //Final Auction price should at least cover the original debt and Liquidation Initiator Reward.
            //Otherwise there is bad debt.
            if (priceOfVault < openDebt + liquidationInitiatorReward) {
                badDebt = openDebt + liquidationInitiatorReward - priceOfVault;
            } else {
                liquidationPenalty = openDebt * claimRatios_.penalty / 100;
                remainder = priceOfVault - openDebt - liquidationInitiatorReward;

                //Check if the remainder can cover the full liquidation penalty
                if (remainder > liquidationPenalty) {
                    //If yes, calculate the final remainder
                    remainder -= liquidationPenalty;
                } else {
                    //If not, there is no remainder for the originalOwner.
                    liquidationPenalty = remainder;
                    remainder = 0;
                }
            }
        }
    }
}
