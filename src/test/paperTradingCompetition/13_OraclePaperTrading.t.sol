// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../paperTradingCompetition/Oracles/OraclePaperTrading.sol";
import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../utils/Constants.sol";



contract OraclePaperTradingInheritedTest is DSTest {

    Vm private vm = Vm(HEVM_ADDRESS);
    OraclePaperTrading private oracle;
    //  FactoryPaperTrading internal factoryContr;
    //  StablePaperTrading private stableUsd;
    //  TokenShop private tokenShop;

    uint8 public decimals = uint8(Constants.oracleStableToUsdDecimals);

    address private creatorAddress = address(1);
    address public transmitter = address(36);
    address public nonTransmitter = address(31);


    constructor() {
        vm.startPrank(creatorAddress);
        oracle = new OraclePaperTrading(uint8(decimals), "masUSD / USD", address(812));
        oracle.setOffchainTransmitter(transmitter);
        vm.stopPrank();
    }

    function testTransmit(address unprivilegedAddress) public {
        vm.startPrank(transmitter);
        int192 answerToTransmit = int192(int256(10 ** decimals));
        oracle.transmit(answerToTransmit);
        int256 answerFromOracle;
        (, answerFromOracle,,,) = oracle.latestRoundData();
        assertEq(answerFromOracle, answerToTransmit);
        vm.stopPrank();
    }
}