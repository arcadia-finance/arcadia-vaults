/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IPricingModule {
    struct GetValueInput {
        address assetAddress;
        uint256 assetId;
        uint256 assetAmount;
        uint256 baseCurrency;
    }

    function getAssetInformation(address asset) external view returns (uint64, address, address[] memory);

    function isAssetAddressWhiteListed(address) external view returns (bool);

    function isWhiteListed(address, uint256) external view returns (bool);

    function getValue(GetValueInput memory) external view returns (uint256, uint256);
}
