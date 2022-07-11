/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";

import "../../utils/Constants.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";
import "../../../lib/forge-std/src/Test.sol";

contract ArcadiaOracleTest is Test {
    using stdStorage for StdStorage;

    uint8 public decimals = uint8(Constants.oracleStableToUsdDecimals);

    address public nonCreator = address(1);
    address public transmitter = address(32);
    address public nonTransmitter = address(31);

    // FIXTURES
    ArcadiaOracleFixture internal arcadiaOracleFixture =
        new ArcadiaOracleFixture(transmitter);

    function testTransmit() public {
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
            uint8(decimals),
            "masUSD / USD",
            address(812)
        );
        int192 answerToTransmit = int192(int256(10**decimals));
        arcadiaOracleFixture.transmitOracle(oracle, answerToTransmit);
        int256 answerFromOracle;
        (, answerFromOracle, , , ) = oracle.latestRoundData();
        assertEq(answerFromOracle, answerToTransmit);
    }

    function testOnlyTransmitter() public {
        // given: oracle initialized by defaultCreatorAddress
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
            uint8(decimals),
            "masUSD / USD",
            address(812)
        );

        // when: nonTransmitter tries to transmit
        int192 answerToTransmit = int192(int256(11**decimals));
        vm.prank(nonTransmitter);

        // then: nonTransmitter shouldn not be able to add new transmission
        vm.expectRevert("Oracle: caller is not the valid transmitter");
        oracle.transmit(answerToTransmit);
        vm.stopPrank();
    }

    function testSetNewTransmitter() public {
        // given: oracle initialized by defaultCreatorAddress
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
            uint8(decimals),
            "masUSD / USD",
            address(812)
        );

        // when: defaultCreatorAddress should be able to add new transmitter, and adds
        vm.prank(arcadiaOracleFixture.defaultCreatorAddress());
        oracle.setOffchainTransmitter(nonTransmitter);
        vm.stopPrank();

        // then: new transmitter should be able to transmit
        int192 answerToTransmit = int192(int256(11**decimals));
        vm.prank(nonTransmitter);
        oracle.transmit(answerToTransmit);
        vm.stopPrank();

        // and: responses should match
        int256 answerFromOracle;
        (, answerFromOracle, , , ) = oracle.latestRoundData();
        assertEq(answerFromOracle, answerToTransmit);
    }

    function testFailSetNewTransmitter() public {
        // given: oracle initialized by defaultCreatorAddress
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
            uint8(decimals),
            "masUSD / USD",
            address(812)
        );

        // when: nonCreator is pranked
        vm.startPrank(nonCreator);

        // then: should not be able to add new transmitter
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setOffchainTransmitter(nonTransmitter);
        vm.stopPrank();
    }

    function testDeactivateTransmitter() public {
        // given: oracle initialized by defaultCreatorAddress
        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
            uint8(decimals),
            "masUSD / USD",
            address(812)
        );

        // when: defaultCreatorAddress is pranked, and deactivates transmitter
        vm.startPrank(arcadiaOracleFixture.defaultCreatorAddress());
        oracle.deactivateTransmitter(transmitter);
        vm.stopPrank();

        // then: transmitter shouldn not be able to add new transmission
        int192 answerToTransmit = int192(int256(11**decimals));
        vm.prank(transmitter);
        vm.expectRevert("Oracle: transmitter is not active");
        oracle.transmit(answerToTransmit);
        vm.stopPrank();
    }
}
