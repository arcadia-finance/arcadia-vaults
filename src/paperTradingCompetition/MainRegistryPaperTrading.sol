// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
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
