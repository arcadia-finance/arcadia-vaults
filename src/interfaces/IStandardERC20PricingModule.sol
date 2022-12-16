/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IStandardERC20PricingModule {
    function getAssetInformation(address asset) external view returns (uint64, address[] memory);
}
