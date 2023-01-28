/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

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
    uint256 public maxAuctionTime = 14_400; //4 hours in seconds
    uint256 public startPriceMultiplier; //2 decimals

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
     * @notice Sets the maximum auction time on the liquidator.
     * @dev The maximum auction time is the time from starting an auction to
     * the moment the price of the auction has decreased to 0.
     * The maxAuctionTime controls the speed of decrease of the auction price.
     * @param maxAuctionTime_ The new maximum auction time.
     */
    function setMaxAuctionTime(uint256 maxAuctionTime_) external onlyOwner {
        maxAuctionTime = maxAuctionTime_;
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

        price = _calcPriceOfVault(auctionInformation[vault].startTime, auctionInformation[vault].openDebt);
    }

    /**
     * @notice Function returns the current auction price given time passed and the openDebt.
     * @param startTime The timestamp when the auction started.
     * @param openDebt The open debt taken by `originalOwner`.
     * @return price The total price for which the vault can be purchased.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function _calcPriceOfVault(uint256 startTime, uint256 openDebt) internal view returns (uint256 price) {
        uint256 auctionTime = block.timestamp - startTime; //Can be unchecked

        if (auctionTime > maxAuctionTime) {
            //ヽ༼ຈʖ̯ຈ༽ﾉ
            price = 0;
        } else {
            price = uint256(openDebt) * startPriceMultiplier * (maxAuctionTime - auctionTime) / maxAuctionTime / 100;
        }
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
