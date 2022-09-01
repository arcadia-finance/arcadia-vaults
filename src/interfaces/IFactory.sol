/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IFactory {
    function isVault(address vaultAddress) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external;

    function liquidate(address vault) external returns (bool);

    function vaultIndex(address vaultAddress) external view returns (uint256);

    function getCurrentRegistry() external view returns (address);

    function addBaseCurrency(uint256 baseCurrency, address liquidityPool, address stable) external;

    function baseCurrencyCounter() external view returns (uint256);

    function baseCurrencyToStable(uint256) external view returns (address);

    function baseCurrencyToLiquidityPool(uint256) external view returns (address);
}
