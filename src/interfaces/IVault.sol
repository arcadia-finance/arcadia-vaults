/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IVault {
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function initialize(address owner, address registry, uint16 latestVaultVersion, address baseCurrency) external;

    function liquidateVault()
        external
        returns (address originalOwner, uint128 openDebt, address baseCurrency, address trustedCreditor);

    function upgradeVault(address, uint16) external;

    function vaultVersion() external view returns (uint8);

    function trustedCreditor() external view returns (address);
}
