/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

pragma solidity >=0.4.22 <0.9.0;

interface IAToken {
    /**
     * @notice Returns the underlying asset of the aToken.
     * @return asset Contract address of the underlying ERC20.
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
