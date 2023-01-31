/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IMainRegistry {
    /**
     * @notice Returns number of basecurrencies.
     * @return counter the number of basecurrencies.
     */
    function baseCurrencyCounter() external view returns (uint256);

    /**
     * @notice Add a new asset to the Main Registry.
     * @param asset The address of the asset.
     */
    function addAsset(address asset) external;
}
