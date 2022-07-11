/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IRegistry {
    function batchIsWhiteListed(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds
    ) external view returns (bool);

    function getTotalValue(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 numeraire
    ) external view returns (uint256);

    function getListOfValuesPerCreditRating(
        address[] calldata _assetAddresses,
        uint256[] calldata _assetIds,
        uint256[] calldata _assetAmounts,
        uint256 numeraire
    ) external view returns (uint256[] memory);
}
