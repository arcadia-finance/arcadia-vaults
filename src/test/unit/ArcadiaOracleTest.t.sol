// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../utils/Constants.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";
import "../../../lib/ds-test/src/test.sol";


contract ArcadiaOracleTest is DSTest {

    uint8 public decimals = uint8(Constants.oracleStableToUsdDecimals);

    address public transmitter = address(32);
    address public nonTransmitter = address(31);

    // FIXTURES
    ArcadiaOracleFixture internal arcadiaOracleFixture = new ArcadiaOracleFixture(transmitter);

    function testTransmit() public {
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(uint8(decimals), "masUSD / USD", address(812));
        int192 answerToTransmit = int192(int256(10 ** decimals));
        arcadiaOracleFixture.transmitOracle(oracle, answerToTransmit);
        int256 answerFromOracle;
        (, answerFromOracle,,,) = oracle.latestRoundData();
        assertEq(answerFromOracle, answerToTransmit);
    }
}