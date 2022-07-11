/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IFactory.sol";

interface IFactoryPaperTrading is IFactory {
    function getVaultAddress(uint256 id) external view returns (address);
}
