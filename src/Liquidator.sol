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
    uint256 public maxAuctionTime = 14_400; //4 hours in seconds
    uint256 public startPriceMultiplier; //2 decimals

    address public factory;
    address public registry;
    address public reserveFund;
    address public treasury;

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

    /**
     * @notice Sets the protocol treasury address on the liquidator.
     * @dev The protocol treasury is used to receive liquidation rewards.
     * @param treasury_ the protocol treasury.
     */
    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
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
        auctionInformation[msg.sender].startTime = uint128(block.timestamp);
        auctionInformation[msg.sender].originalOwner = originalOwner;
        auctionInformation[msg.sender].openDebt = openDebt;
        auctionInformation[msg.sender].baseCurrency = baseCurrency;
        auctionInformation[msg.sender].trustedCreditor = trustedCreditor;

        //Initiator can immediately claim the initiator reward.
        //In edge cases, there might not be sufficient funds on this Liquidator contract,
        //and the initiator will have to wait untill the auction of collateral is finished.
        openClaims[liquidationInitiator][baseCurrency] += calcLiquidationInitiatorReward(openDebt);
    }

    /**
     * @notice Calculates the Reward in baseCurrency for the Liquidation Initiator.
     * @param openDebt the open debt taken by `originalOwner`, denominated in baseCurrency.
     * @return liquidationInitiatorReward The Reward for the Liquidation Initiator, denominated in baseCurrency.
     */
    function calcLiquidationInitiatorReward(uint256 openDebt)
        public
        view
        returns (uint256 liquidationInitiatorReward)
    {
        //Calculate liquidationInitiatorreward as the minimum between a percentage of a position capped by a certain amount
        //ToDo: How are we going to cap the max?
        liquidationInitiatorReward = openDebt * claimRatios.initiatorReward / 100;
    }

    /**
     * @notice Function returns the current auction price of a vault.
     * @param vaultAddress the vaultAddress.
     * @return price the total price for which the vault can be purchased.
     * @return inAuction returns false when the vault is not being auctioned.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function getPriceOfVault(address vaultAddress) public view returns (uint256 price, bool inAuction) {
        inAuction = auctionInformation[vaultAddress].inAuction;

        if (!inAuction) {
            return (0, false);
        }

        uint256 auctionTime = block.timestamp - auctionInformation[vaultAddress].startTime; //Can be unchecked

        if (auctionTime > maxAuctionTime) {
            //ヽ༼ຈʖ̯ຈ༽ﾉ
            price = 0;
        } else {
            price = uint256(auctionInformation[vaultAddress].openDebt) * startPriceMultiplier
                * (maxAuctionTime - auctionTime) / maxAuctionTime / 100;
        }

        return (price, inAuction);
    }

    /**
     * @notice Function a user (the bidder) calls to buy the vault during the auction process.
     * @param vaultAddress the vaultAddress of the vault the user want to buy.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the vault
     * And immediately ends the auction.
     */
    function buyVault(address vaultAddress) public {
        //Check if the Vault is indeed for sale and get the current price.
        (uint256 priceOfVault, bool inAuction) = getPriceOfVault(vaultAddress);
        require(inAuction, "LQ_BV: Not for sale");

        //Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[vaultAddress].inAuction = false;
        //ToDo: set all other auction information to 0?

        //Transfer funds, equal to the current auction price from the bidder to the Liquidation contract.
        //The bidder should have approved the Liquidation contract for at least an amount of priceOfVault.
        address baseCurrency = auctionInformation[vaultAddress].baseCurrency;
        require(
            IERC20(baseCurrency).transferFrom(msg.sender, address(this), priceOfVault), "LQ_BV: transfer from failed"
        );

        //fetch the contract address of the Creditor and the total amount of liabilities that need to be repaid.
        address trustedCreditor = auctionInformation[vaultAddress].trustedCreditor;
        uint256 openDebt = auctionInformation[vaultAddress].openDebt;
        uint256 liquidationInitiatorReward = calcLiquidationInitiatorReward(openDebt);

        if (priceOfVault < openDebt + liquidationInitiatorReward) {
            //Auction proceeds do not cover all liabilities (debt + reward for the liquidation initiator)
            uint256 badDebt = openDebt + liquidationInitiatorReward - priceOfVault;

            //In the worst case scenario, auction proceeds do not even cover the reward for the liquidation initiator.
            //In this edge case there are not enough funds on the Liquidator contract to honour all openClaims.
            //The missing funds (deficit) have be transferred from the tustedCreditor to this Liquidator contract
            //via the function settleLiquidation(uint256, uint256).
            uint256 deficit = priceOfVault < liquidationInitiatorReward ? liquidationInitiatorReward - priceOfVault : 0;

            if (deficit == 0) {
                //No deficit, transfer the auction proceeds (minus Liquidation Initiator reward back to the trustedcreditor).
                //Since liabilities (openDebt) are not fully paid off, the trusted Creditor has to write off an amount of badDebt.
                require(IERC20(baseCurrency).transfer(trustedCreditor, openDebt - badDebt), "LQ_BV: transfer failed");
            }

            //Trigger Logic on the Trusted Creditor to write off badDebt, and in the unlikely case there is a deficit,
            //trigger a transfer from Trusted Creditor back to the Liquidator.
            ILendingPool(trustedCreditor).settleLiquidation(badDebt, deficit);
        } else {
            //Auction proceeds do cover all liabilities (debt + reward for the liquidation initiator).
            //Full amount of debt owed to the Creditor is paid off.
            //No need to trigger any additional logic on Trusted Creditor.
            require(IERC20(baseCurrency).transfer(trustedCreditor, openDebt), "LQ_BV: transfer failed");

            //Calculate Liquidation Penalty, any funds remaining after the liabilities and the liquidation penalty are paid off,
            //Go back to the Original Owner off the vault.
            (uint256 liquidationPenalty, uint256 remainder) =
                calcLiquidationPenalty(priceOfVault, openDebt, liquidationInitiatorReward);

            //After the auction the treasury can claim the liquidationPenalty and the originalOwner any remaining assets.
            //ToDo: should the treasury claim the liquidationPenalty, or should it immediately be send to the Lending pool?
            openClaims[treasury][baseCurrency] += liquidationPenalty;
            if (remainder != 0) openClaims[auctionInformation[vaultAddress].originalOwner][baseCurrency] += remainder;
        }

        //Change ownership of the auctioned vault to the bidder.
        //Todo: transfer a vault imediately on vault address instead of ID.
        IFactory(factory).safeTransferFrom(address(this), msg.sender, vaultAddress);
    }

    /**
     * @notice Calculates the Liquidation Penalty in baseCurrency and the remainder.
     * @param priceOfVault the price for which the vault is auctioned, denominated in baseCurrency.
     * @param openDebt the open debt taken by `originalOwner`, denominated in baseCurrency.
     * @param liquidationInitiatorReward The Reward for the Liquidation Initiator, denominated in baseCurrency.
     * @return liquidationPenalty The Liquidation Penalty, denominated in baseCurrency.
     * @return remainder The remaining funds after the liabilities and the liquidation penalty are paid off, denominated in baseCurrency.
     */
    function calcLiquidationPenalty(uint256 priceOfVault, uint256 openDebt, uint256 liquidationInitiatorReward)
        public
        view
        returns (uint256 liquidationPenalty, uint256 remainder)
    {
        //Intermediate result of the remainder
        remainder = priceOfVault - openDebt - liquidationInitiatorReward;

        //Max amount of the liquidation penalty
        liquidationPenalty = openDebt * claimRatios.penalty / 100;

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

    /*///////////////////////////////////////////////////////////////
                    CLAIM AUCTION PROCEEDS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim auction proceeds.
     * @param baseCurrency The address of the claimable asset, an ERC20 token.
     * @param amount The amount of tokens claimed.
     */
    function claim(address baseCurrency, uint256 amount) public {
        //Will revert if msg.sender want to claim more than their open claims
        openClaims[msg.sender][baseCurrency] -= amount;
        IERC20(baseCurrency).transfer(msg.sender, amount);
    }
}
