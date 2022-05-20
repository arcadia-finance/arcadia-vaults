// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../7_Factory.t.sol";
import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";

contract FactoryPaperTradingTest is factoryTest {

  FactoryPaperTrading private factoryContr;
  VaultPaperTrading private vaultContr;
  ERC20PaperTrading private erc20Contr;

  constructor() factoryTest() {
    factoryContr = new FactoryPaperTrading();
    vaultContr = new VaultPaperTrading();
    erc20Contr = new ERC20PaperTrading("ERC20 Mock", "mERC20", 18, 0x0000000000000000000000000000000000000000);
  }

}