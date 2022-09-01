/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../../../lib/forge-std/src/Test.sol";
import "../../../libraries/AssetConfiguration.sol";


contract AssetConfigurationTest is Test {
    using stdStorage for StdStorage;

    uint8 public decimals = uint8(18);

    address public nonCreator = address(1);
    address public transmitter = address(32);
    address public nonTransmitter = address(31);



    function testSetCollateralFactor() public {
        // Given: the initialConfig with all configuration parameters zero for the asset
        AssetConfiguration.AssetDetailBitmap memory initialConfig = AssetConfiguration.AssetDetailBitmap({data: uint128(0)});

        // When: The collateral factor is fetch from the config
        uint256 collateralFactor1 = AssetConfiguration.getCollateralFactor(initialConfig);

        // Then: It should be zero, because it is not set.
        assertEq(collateralFactor1, 0);

        // Then Given: The collateral ratio is set as 1
        AssetConfiguration.setCollateralFactor(initialConfig, uint128(1));

        // When: The collateral factor is fetched
        uint256 collateralFactor2 = AssetConfiguration.getCollateralFactor(initialConfig);

        // Then: New collateral factor should be 1 not 0
        assertEq(collateralFactor2, 1);
        assertTrue(collateralFactor2 != 0);

    }
//
//    function testTransmit() public {
//        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
//            uint8(decimals),
//            "masUSD / USD",
//            address(812)
//        );
//        int192 answerToTransmit = int192(int256(10**decimals));
//        arcadiaOracleFixture.transmitOracle(oracle, answerToTransmit);
//        int256 answerFromOracle;
//        (, answerFromOracle, , , ) = oracle.latestRoundData();
//        assertEq(answerFromOracle, answerToTransmit);
//    }
//
//    function testOnlyTransmitter() public {
//        // given: oracle initialized by defaultCreatorAddress
//        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
//            uint8(decimals),
//            "masUSD / USD",
//            address(812)
//        );
//
//        // when: nonTransmitter tries to transmit
//        int192 answerToTransmit = int192(int256(11**decimals));
//        vm.prank(nonTransmitter);
//
//        // then: nonTransmitter shouldn not be able to add new transmission
//        vm.expectRevert("Oracle: caller is not the valid transmitter");
//        oracle.transmit(answerToTransmit);
//        vm.stopPrank();
//    }
//
//    function testSetNewTransmitter() public {
//        // given: oracle initialized by defaultCreatorAddress
//        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
//            uint8(decimals),
//            "masUSD / USD",
//            address(812)
//        );
//
//        // when: defaultCreatorAddress should be able to add new transmitter, and adds
//        vm.prank(arcadiaOracleFixture.defaultCreatorAddress());
//        oracle.setOffchainTransmitter(nonTransmitter);
//        vm.stopPrank();
//
//        // then: new transmitter should be able to transmit
//        int192 answerToTransmit = int192(int256(11**decimals));
//        vm.prank(nonTransmitter);
//        oracle.transmit(answerToTransmit);
//        vm.stopPrank();
//
//        // and: responses should match
//        int256 answerFromOracle;
//        (, answerFromOracle, , , ) = oracle.latestRoundData();
//        assertEq(answerFromOracle, answerToTransmit);
//    }
//
//    function testFailSetNewTransmitter() public {
//        // given: oracle initialized by defaultCreatorAddress
//        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
//            uint8(decimals),
//            "masUSD / USD",
//            address(812)
//        );
//
//        // when: nonCreator is pranked
//        vm.startPrank(nonCreator);
//
//        // then: should not be able to add new transmitter
//        vm.expectRevert("Ownable: caller is not the owner");
//        oracle.setOffchainTransmitter(nonTransmitter);
//        vm.stopPrank();
//    }
//
//    function testDeactivateTransmitter() public {
//        // given: oracle initialized by defaultCreatorAddress
//        ArcadiaOracle oracle = arcadiaOracleFixture.initOracle(
//            uint8(decimals),
//            "masUSD / USD",
//            address(812)
//        );
//
//        // when: defaultCreatorAddress is pranked, and deactivates transmitter
//        vm.startPrank(arcadiaOracleFixture.defaultCreatorAddress());
//        oracle.deactivateTransmitter(transmitter);
//        vm.stopPrank();
//
//        // then: transmitter shouldn not be able to add new transmission
//        int192 answerToTransmit = int192(int256(11**decimals));
//        vm.prank(transmitter);
//        vm.expectRevert("Oracle: transmitter is not active");
//        oracle.transmit(answerToTransmit);
//        vm.stopPrank();
//    }
}
