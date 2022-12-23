/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity >=0.4.22 <0.9.0;

interface ITrustedProtocol {
    function openMarginAccount() external returns (bool success, address pToken, address baseCurrency);

    function getOpenPosition(address vault) external view returns (uint256 openPosition);
}
