// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity ^0.8.13;

import "../../interfaces/IVault.sol";

/// @title VaultActionMixin Contract
/// @author Enzyme Council <security@enzyme.finance>
/// @notice A mixin contract for extensions that can make vault calls

//Vault calls IM

abstract contract VaultActionMixin {
    /// @notice Grants an allowance to a spender to use a fund's asset
    /// @param _asset The asset for which to grant an allowance
    /// @param _target The spender of the allowance
    /// @param _amount The amount of the allowance
    function __approveAssetSpender(
        address _vault,
        address _asset,
        address _target,
        uint256 _amount
    ) internal {
        //Approve _target to control _amount of _asset owned by _vault
        //To Implement
    }

    /// @notice Withdraws an asset from the Vault to a given account
    /// @param _asset The asset to withdraw
    /// @param _target The account to which to withdraw the asset
    /// @param _amount The amount of asset to withdraw
    function __withdrawAssetTo(
        address _vault,
        address _asset,
        address _target,
        uint256 _amount
    ) internal {
        //To Implement
    }
}