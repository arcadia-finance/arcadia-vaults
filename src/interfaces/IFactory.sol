/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IFactory {
    /**
     * @notice Checks if a contract is a Vault.
     * @param vault The contract address of the Vault.
     * @return bool indicating if the address is a vault or not.
     */
    function isVault(address vault) external view returns (bool);

    /**
     * @notice Function used to transfer a vault between users.
     * @param from The sender.
     * @param to The target.
     * @param vault The address of the vault that is transferred.
     */
    function safeTransferFrom(address from, address to, address vault) external;

    /**
     * @notice Function called by a Vault at the start of a liquidation to transfer ownership to the Liquidator contract.
     * @param liquidator The contract address of the liquidator.
     */
    function liquidate(address liquidator) external;
}
