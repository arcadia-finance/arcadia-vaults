// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;


import "../../FactoryPaperTrading.sol";
import "../../../Proxy.sol";
import "../../StablePaperTrading.sol";
import "../../../utils/Constants.sol";
import "../../Oracles/StableOracle.sol";
import "../../../mockups/SimplifiedChainlinkOracle.sol";
import "../../../utils/Strings.sol";

contract DeployContractsOne  {

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

  function deployStable(string calldata a, string calldata b, uint8 c, address d, address e) public returns (address) {
    StablePaperTrading stab = new StablePaperTrading(a, b, c, d, e);
    stab.transferOwnership(msg.sender);
    return address(stab);
  }

  function deployOracle(uint8 a, string calldata b) external returns (address) {
    SimplifiedChainlinkOracle orac = new SimplifiedChainlinkOracle(a, b);
    orac.transferOwnership(msg.sender);
    return address(orac);
  }

  function deployOracleStable(uint8 a, string calldata b) external returns (address) {
    StableOracle orac = new StableOracle(a, b);
    orac.transferOwnership(msg.sender);
    return address(orac);
  }

}
