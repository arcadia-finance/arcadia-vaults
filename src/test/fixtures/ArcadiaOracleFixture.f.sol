/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../../lib/forge-std/src/Test.sol";

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../utils/Constants.sol";
import "../../mockups/ArcadiaOracle.sol";

contract ArcadiaOracleFixture is Test {
    uint8 public defaultDecimals = uint8(18);

    address public defaultCreatorAddress = address(1);
    address public defaultTransmitter;

    constructor(address transmitter) {
        defaultTransmitter = transmitter;
    }

    function initOracle(uint8 decimals, string memory description, address asset_address)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            asset_address
        );
        oracle.setOffchainTransmitter(defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function initOracle(
        address creatorAddress,
        uint8 decimals,
        string memory description,
        address asset_address,
        address transmitterAddress
    ) public returns (ArcadiaOracle) {
        vm.startPrank(creatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            asset_address
        );
        oracle.setOffchainTransmitter(transmitterAddress);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description, uint256 answer)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(defaultTransmitter);
        vm.stopPrank();
        vm.startPrank(defaultTransmitter);
        int256 convertedAnswer = int256(answer);
        oracle.transmit(convertedAnswer);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description) public returns (ArcadiaOracle) {
        vm.startPrank(defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
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
