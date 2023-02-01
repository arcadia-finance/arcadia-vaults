/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity ^0.8.13;

interface IVault {
    /**
     * @notice Returns the Vault version.
     * @return verion The Vault version.
     */
    function vaultVersion() external view returns (uint16);

    /**
     * @notice Initiates the variables of the vault
     * @param owner The tx.origin: the sender of the 'createVault' on the factory
     * @param registry The 'beacon' contract to which should be looked at for external logic.
     * @param vaultVersion The version of the vault logic.
     * @param baseCurrency The Base-currency in which the vault is denominated.
     */
    function initialize(address owner, address registry, uint16 vaultVersion, address baseCurrency) external;

    /**
     * @notice Stores a new address in the EIP1967 implementation slot & updates the vault version.
     * @param newImplementation The contract with the new vault logic.
     * @param newVersion The new version of the vault logic.
     */
    function upgradeVault(address newImplementation, address newRegistry, uint16 newVersion, bytes calldata data)
        external;

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Vault
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Function called by Liquidator to start liquidation of the Vault.
     * @param openDebt The open debt taken by `originalOwner` at moment of liquidation at trustedCreditor
     * @return originalOwner The original owner of this vault.
     * @return baseCurrency The baseCurrency in which the vault is denominated.
     * @return trustedCreditor The account or contract that is owed the debt.
     */
    function liquidateVault(uint256 openDebt) external returns (address, address, address);
}
