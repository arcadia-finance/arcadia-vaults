/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract ArcadiaOracle is Ownable {
    // Configs
    address public asset_address;
    uint8 public decimals;
    string public description;

    uint8 private latestRoundId;

    // Transmission records the median answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int256 answer;
        uint64 timestamp;
    }

    mapping(uint32 => Transmission) /* aggregator round ID */
        internal transmissions;

    enum Role {
        Unset, // unset
        Transmitter, // Offchain data transmissions to the oracle
        Validator // Offchain data validator for the setted values
    }
    struct OffchainConnector {
        Role role; // role of the connector
        bool isActive; // is the connector still active
    }

    mapping(address => OffchainConnector) internal offchain_connectors;

    constructor(
        uint8 _decimals,
        string memory _description,
        address _asset_address
    ) {
        decimals = _decimals;
        description = _description;
        asset_address = _asset_address;
        latestRoundId = 0;
    }

    /**
     * @notice setOffchainTransmitter set the offchain transmitter to transmit new data, multiple transmitter is possible,
     * @param _transmitter address of the transmitter
     */
    function setOffchainTransmitter(address _transmitter) public onlyOwner {
        require(
            offchain_connectors[_transmitter].role != Role.Transmitter,
            "Oracle: Address is already saved as Transmitter!"
        );
        offchain_connectors[_transmitter] = OffchainConnector({
            isActive: true,
            role: Role.Transmitter
        });
    }

    /**
     * @notice deactivateTransmitter set the offchain transmitter state to deactive
     * @param _transmitter address of the transmitter
     */
    function deactivateTransmitter(address _transmitter) public onlyOwner {
        require(
            offchain_connectors[_transmitter].role == Role.Transmitter,
            "Oracle: Address is not Transmitter!"
        );
        offchain_connectors[_transmitter].isActive = false;
    }

    /**
     * @dev Throws if called by any account other than the transmitter.
     */
    modifier onlyTransmitter() {
        require(
            offchain_connectors[_msgSender()].role == Role.Transmitter,
            "Oracle: caller is not the valid transmitter"
        );
        require(
            offchain_connectors[_msgSender()].isActive,
            "Oracle: transmitter is not active"
        );
        _;
    }

    /**
     * @notice transmit is called to post a new report to the contract
     * @param _answer the new price data for the round
     */
    function transmit(int256 _answer) public onlyTransmitter {
        unchecked {
            latestRoundId++;
        }
        transmissions[latestRoundId] = Transmission(
            _answer,
            uint64(block.timestamp)
        );
    }

    /**
     * @notice oracle answer for latest rounddata
     * @return roundId aggregator round of latest report
     * @return answer latest report
     * @return startedAt timestamp of block containing latest report
     * @return updatedAt timestamp of block containing latest report
     * @return answeredInRound aggregator round of latest report
     */
    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = latestRoundId;
        require(roundId != 0, "Oracle: No data present!");

        return (
            roundId,
            transmissions[uint32(roundId)].answer,
            transmissions[uint32(roundId)].timestamp,
            transmissions[uint32(roundId)].timestamp,
            roundId
        );
    }
}
