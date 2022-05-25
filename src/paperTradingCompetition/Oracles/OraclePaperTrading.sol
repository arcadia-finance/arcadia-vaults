// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract OraclePaperTrading is Ownable {

    // Configs
    address public asset_address;
    uint8 public decimals;
    string public description;


    uint8 private latestRoundId;

    // Transmission records the median answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int192 answer; // 192 bits ought to be enough for anyone
        uint64 timestamp;
    }

    mapping(uint32 /* aggregator round ID */ => Transmission) internal transmissions;

    enum Role {
        Transmitter, // Offchain data transmissions to the oracle
        Validator, // Offchain data validator for the setted values
        Unset // unset
    }
    struct OffchainConnector {
        Role role; // role of the connector
        bool isActive; // is the connector still active
    }

    mapping(address => OffchainConnector) internal offchain_connectors;


    constructor (uint8 _decimals, string memory _description, address _asset_address) {
        decimals = _decimals;
        description = _description;
        asset_address = _asset_address;
        latestRoundId = 0;
    }

    function setOffchainTransmitter(address _transmitter) public onlyOwner {
        offchain_connectors[_transmitter] = OffchainConnector({
            isActive : true,
            role : Role.Transmitter
            }
        );

    }

    /**
     * @dev Throws if called by any account other than the transmitter.
     */
    modifier onlyTransmitter() {
        require(offchain_connectors[_msgSender()].role == Role.Transmitter, "Oracle: caller is not the valid transmitter");
        _;
    }

    function transmit(int192 _answer) public onlyTransmitter {
        latestRoundId++;
        transmissions[latestRoundId] = Transmission(
            _answer, uint64(block.timestamp)
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
        require(roundId != 0, "No data present!");

        Transmission memory transmission = transmissions[uint32(roundId)];
        return (
            roundId,
            transmission.answer,
            transmission.timestamp,
            transmission.timestamp,
            roundId
        );
    }
}