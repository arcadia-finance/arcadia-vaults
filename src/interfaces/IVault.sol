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

    function initialize(address _owner, address registryAddress, uint16 latestVaultVersion) external;

    function liquidateVault(address liquidationKeeper) external returns (bool, address);

    function upgradeVault(address, uint16) external;

    function vaultVersion() external view returns (uint8);

    function trustedProtocol() external view returns (address);

    function vaultManagementAction(address _actionHandler, bytes memory _actionData) external;

    function approveAssetForActionHandler(address _target, address _asset, uint256 _amount) external;

    function getCollateralValue() external view returns (uint256);

    function getUsedMargin() external view returns (uint128 usedMargin);
}
