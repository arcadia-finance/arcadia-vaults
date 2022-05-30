// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../utils/Constants.sol";
import "../fixtures/ArcadiaOracleFixture.sol";


contract OraclePaperTradingInheritedTest is ArcadiaOracleFixture {

    uint8 public decimals = uint8(Constants.oracleStableToUsdDecimals);

    address public transmitter = address(32);
    address public nonTransmitter = address(31);


    constructor() {
    }

    function testTransmit() public {
        ArcadiaOracle oracle = ArcadiaOracleFixture.initOracle(uint8(decimals), "masUSD / USD", address(812), transmitter);
//        vm.startPrank(transmitter);
        int192 answerToTransmit = int192(int256(10 ** decimals));
        ArcadiaOracleFixture.transmitOracle(oracle, answerToTransmit);
        int256 answerFromOracle;
        (, answerFromOracle,,,) = oracle.latestRoundData();
        assertEq(answerFromOracle, answerToTransmit);
    }
}