/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IStandardERC20PricingModule {
    /**
     * @notice Returns the information that is stored in the StandardERC20PricingModule for a given ERC20 token.
     * @param asset The Token address of the asset.
     * @return assetUnit The unit (10 ** decimals) of the asset.
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD.
     */
    function getAssetInformation(address asset) external view returns (uint64, address[] memory);
}
