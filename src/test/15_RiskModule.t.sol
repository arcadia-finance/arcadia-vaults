/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/forge-std/src/Test.sol";
import "../RiskModule.sol";
import "./gasTests/BuyVault1.sol";

contract RiskModuleTest is Test {
    using stdStorage for StdStorage;

    address public creator = address(1);
    address public nonCreator = address(2);

    RiskModule public riskModule;
    // These code will run before all the tests

    constructor() {
        vm.startPrank(creator);
        riskModule = new RiskModule();
        vm.stopPrank();
    }
}
