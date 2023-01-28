/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IFactory {
    function isVault(address vaultAddress) external view returns (bool);

    function safeTransferFrom(address from, address to, address vault) external;

    function safeTransferFrom(address from, address to, uint256 id) external;

    function liquidate(address liquidator) external;

    function vaultIndex(address vaultAddress) external view returns (uint256);

    function getCurrentRegistry() external view returns (address);
}
