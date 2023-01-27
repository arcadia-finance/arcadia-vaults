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
import {LogExpMath} from "./utils/LogExpMath.sol";
import {ITrustedCreditor} from "./interfaces/ITrustedCreditor.sol";

/**
 * @title The liquidator holds the execution logic and storage or all things related to liquidating Arcadia Vaults
 * @author Arcadia Finance
 * @notice Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev contact: dev at arcadia.finance
 */
contract Liquidator is Ownable {
    uint256 public startPriceMultiplier; // 2 decimals
    // @dev 18 decimals, it is calculated off-chain and set by the owner
    // It is discount for auction per second passed after the auction.
    // example: 999807477651317500, it is calculated based on the half-life of 1 hour
    uint256 public discountRate;
    uint256 public auctionCutoffTime;

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
     * @notice Sets the discount rate for the liquidator.
     * @dev The discount rate is a multiplier that is used to decrease the price of the auction over time.
     * @param halfLife The new half life
     */
    function setDiscountRate(uint256 halfLife) external onlyOwner {
        require(halfLife > 30 * 60, "LQ_DR: It must be in limits");
        require(halfLife < 8 * 60 * 60, "LQ_DR: It must be in limits");
        discountRate = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLife));
    }

    /**
     * @notice Sets the max cutoff time for the liquidator.
     * @dev The max cutoff time is the maximum time an auction can run.
     * @param auctionCutoffTime_ The new max cutoff time
     */
    function setAuctionCutoffTime(uint256 auctionCutoffTime_) external onlyOwner {
        require(auctionCutoffTime_ > 1 * 60 * 60, "LQ_ACT: It must be in limits");
        require(auctionCutoffTime_ < 8 * 60 * 60, "LQ_ACT: It must be in limits");
        auctionCutoffTime = auctionCutoffTime_;
    }

    /**
     * @notice Sets the start price multiplier for the liquidator.
     * @dev The start price multiplier is a multiplier that is used to increase the price of the auction over time.
     * @param startPriceMultiplier_ The new start price multiplier.
     */
    function setStartPriceMultiplier(uint16 startPriceMultiplier_) external onlyOwner {
        require(startPriceMultiplier_ > 100, "LQ_SPM: It must be in limits");
        require(startPriceMultiplier_ < 301, "LQ_SPM: It must be in limits");
        startPriceMultiplier = uint256(startPriceMultiplier_);
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
     */
    function _calcPriceOfVault(uint256 timePassed, uint256 openDebt) internal view returns (uint256 price) {
        uint256 auctionTime;
        unchecked {
            auctionTime = timePassed * 1_000_000_000_000_000_000;
        }
        price = uint256(openDebt) * startPriceMultiplier * LogExpMath.pow(discountRate, auctionTime)
            / 100_000_000_000_000_000_000;
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

        uint256 priceOfVault = _calcPriceOfVault(auctionInformation_.startTime, auctionInformation_.openDebt);

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
        liquidationInitiatorReward = openDebt * claimRatios_.initiatorReward / 100;

        if (priceOfVault < openDebt + liquidationInitiatorReward) {
            badDebt = openDebt + liquidationInitiatorReward - priceOfVault;
        } else {
            liquidationPenalty = openDebt * claimRatios_.penalty / 100;
            remainder = priceOfVault - openDebt - liquidationInitiatorReward;

            //Check if the remainder can cover the full liquidation penalty
            if (liquidationPenalty > remainder) {
                //If yes, calculate the final remainder
                remainder -= liquidationPenalty;
            } else {
                //If not, there is no remainder for the originalOwner.
                remainder = 0;
                liquidationPenalty = remainder;
            }
        }
    }
}
