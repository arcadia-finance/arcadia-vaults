/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

pragma solidity ^0.8.13;

interface IAToken {
    /**
     * @notice Returns the underlying asset of the aToken.
     * @return asset Contract address of the underlying ERC20.
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
