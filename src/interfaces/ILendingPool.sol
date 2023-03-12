/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface ILendingPool {
    /**
     * @notice Settles the liquidation after the auction is finished and pays out Creditor, Original owner and Service providers.
     * @param vault The contract address of the vault.
     * @param originalOwner The original owner of the vault before the auction.
     * @param badDebt The amount of liabilities that was not recouped by the auction.
     * @param liquidationInitiatorReward The Reward for the Liquidation Initiator.
     * @param liquidationFee The additional fee the `originalOwner` has to pay to the protocol.
     * @param remainder Any funds remaining after the auction are returned back to the `originalOwner`.
     */
    function settleLiquidation(
        address vault,
        address originalOwner,
        uint256 badDebt,
        uint256 liquidationInitiatorReward,
        uint256 liquidationFee,
        uint256 remainder
    ) external;
}
