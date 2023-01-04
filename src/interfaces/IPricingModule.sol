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

    struct DepositAllowance {
        bool isWhiteListed;
        uint248 maxExposure;
    }

    function getAssetInformation(address asset) external view returns (uint64, address, address[] memory);

    function setRiskVariablesForAsset(
        address asset,
        uint16[] memory collateralFactors,
        uint16[] memory liquidationThresholds
    ) external;

    function isAssetAddressWhiteListed(address) external view returns (bool, uint248);

    function isWhiteListed(address, uint256) external view returns (bool);
    function processDeposit(address, uint256, uint256) external returns (bool);
    function processWithdrawal(address, uint256) external;

    function getValue(GetValueInput memory) external view returns (uint256, uint256, uint256, uint256);
}
