// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../utils/Constants.sol";
import "../../ArcadiaOracle.sol";


contract ArcadiaOracleFixture is DSTest {

    Vm private vm = Vm(HEVM_ADDRESS);
//    ArcadiaOracle private oracle;

    uint8 public defaultDecimals = uint8(Constants.oracleStableToUsdDecimals);

    address public defaultCreatorAddress = address(1);
    address public defaultTransmitter = address(36);

    constructor(address transmitter) {
        defaultTransmitter = transmitter;
    }

    function initStableOracle(uint8 decimals, string memory description, address asset_address) public returns (ArcadiaOracle oracle){
        vm.startPrank(defaultCreatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, asset_address);
        oracle.setOffchainTransmitter(defaultTransmitter);
        oracle.transmit(int256(10 ** decimals));
        vm.stopPrank();
        return oracle;
    }
    function initStableOracle(uint8 decimals, string memory description) public returns (ArcadiaOracle oracle){
        vm.startPrank(defaultCreatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
        oracle.setOffchainTransmitter(defaultTransmitter);
        oracle.transmit(int256(10 ** decimals));
        vm.stopPrank();
        return oracle;
    }
    function initStableOracle(address creatorAddress, uint8 decimals, string memory description) public returns (ArcadiaOracle oracle){
        vm.startPrank(creatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
        oracle.setOffchainTransmitter(defaultTransmitter);
        oracle.transmit(int256(10 ** decimals));
        vm.stopPrank();
        return oracle;
    }

    function initOracle(uint8 decimals, string memory description, address asset_address) public returns (ArcadiaOracle oracle){
        vm.startPrank(defaultCreatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, asset_address);
        oracle.setOffchainTransmitter(defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }
    function initOracle(address creatorAddress, uint8 decimals, string memory description, address asset_address, address transmitterAddress) public returns (ArcadiaOracle oracle){
        vm.startPrank(creatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, asset_address);
        oracle.setOffchainTransmitter(transmitterAddress);
        vm.stopPrank();
        return oracle;
    }
    function initMockedOracle(uint8 decimals, string memory description, uint answer) public returns (ArcadiaOracle oracle){
        vm.startPrank(defaultCreatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
        oracle.setOffchainTransmitter(defaultTransmitter);
        vm.stopPrank();
        vm.startPrank(defaultTransmitter);
        int256 convertedAnswer = int256(answer);
        oracle.transmit(convertedAnswer);
        vm.stopPrank();
        return oracle;
    }
    function initMockedOracle(uint8 decimals, string memory description) public returns (ArcadiaOracle oracle){
        vm.startPrank(defaultCreatorAddress);
        oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
        oracle.setOffchainTransmitter(defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function transmitOracle(ArcadiaOracle oracle, int256 answer, address transmitter) public {
        vm.startPrank(transmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }
    function transmitOracle(ArcadiaOracle oracle, int256 answer) public {
        vm.startPrank(defaultTransmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }

}