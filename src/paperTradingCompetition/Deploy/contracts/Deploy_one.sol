/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../FactoryPaperTrading.sol";
import "../../../Proxy.sol";
import "../../StablePaperTrading.sol";
import "../../../utils/Constants.sol";
import "../../../utils/Strings.sol";
import "../../../ArcadiaOracle.sol";

contract DeployContractsOne {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployFact() public returns (address) {
        FactoryPaperTrading fact = new FactoryPaperTrading();
        fact.transferOwnership(msg.sender);
        return address(fact);
    }

    function deployStable(
        string calldata a,
        string calldata b,
        uint8 c,
        address d,
        address e
    ) public returns (address) {
        StablePaperTrading stab = new StablePaperTrading(a, b, c, d, e);
        stab.transferOwnership(msg.sender);
        return address(stab);
    }

    function deployOracle(
        uint8 a,
        string calldata b,
        address c
    ) external returns (address) {
        ArcadiaOracle orac = new ArcadiaOracle(a, b, c);
        orac.setOffchainTransmitter(msg.sender);
        orac.transferOwnership(msg.sender);
        return address(orac);
    }

    function deployOracleStable(
        uint8 a,
        string calldata b,
        address c
    ) external returns (address) {
        ArcadiaOracle orac = new ArcadiaOracle(a, b, c);
        orac.setOffchainTransmitter(msg.sender);
        orac.setOffchainTransmitter(address(this));
        orac.transmit(int256(10**a));
        orac.transferOwnership(msg.sender);
        return address(orac);
    }
}
