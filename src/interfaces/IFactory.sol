/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity ^0.8.13;

interface IFactory {
    /**
     * @notice View function returning if an address is a vault.
     * @param vault The address to be checked.
     * @return bool Whether the address is a vault or not.
     */
    function isVault(address vault) external view returns (bool);

    /**
     * @notice Function used to transfer a vault between users.
     * @dev This method transfers a vault not on id but on address and also transfers the vault proxy contract to the new owner.
     * @param from sender.
     * @param to target.
     * @param vault The address of the vault that is about to be transferred.
     */
    function safeTransferFrom(address from, address to, address vault) external;

    /**
     * @notice Function called by a Vault at the start of a liquidation to transfer ownership.
     * @param liquidator The contract address of the liquidator.
     */
    function liquidate(address liquidator) external;
}
