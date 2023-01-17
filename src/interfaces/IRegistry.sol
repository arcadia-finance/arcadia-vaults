/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

interface IRegistry {
    function batchIsWhiteListed(address[] calldata assetAddresses, uint256[] calldata assetIds)
        external
        view
        returns (bool);
    function batchProcessDeposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external;

    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256);

    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256 baseCurrency
    ) external view returns (uint256);

    function getCollateralValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256);

    function getLiquidationValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256);

    function assetToBaseCurrency(address baseCurrency) external view returns (uint8 baseCurrencyIdentifier);

    function batchProcessWithdrawal(address[] calldata, uint256[] calldata) external;
}
