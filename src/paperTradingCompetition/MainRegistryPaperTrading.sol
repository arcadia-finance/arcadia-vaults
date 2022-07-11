/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../AssetRegistry/MainRegistry.sol";

contract MainRegistryPaperTrading is MainRegistry {

    constructor(NumeraireInformation memory _numeraireInformation) 
        MainRegistry(_numeraireInformation) {}

    function getOracleForNumeraire(uint256 numeraire) public view returns (address) {
        require(numeraire < numeraireCounter, "Numeraire does not exist.");
        return numeraireToInformation[numeraire].numeraireToUsdOracle;
    }
}
