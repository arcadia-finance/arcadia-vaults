/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../../InterestRateModule.sol";
import "../../VaultPaperTrading.sol";

contract DeployContractsFour {
    InterestRateModule public interestRateModule;
    VaultPaperTrading public vault;
    VaultPaperTrading public proxy;
    address public proxyAddr;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployIRM() external returns (address) {
        InterestRateModule irm = new InterestRateModule();
        irm.transferOwnership(msg.sender);
        return address(irm);
    }

    function deployVaultLogic() external returns (address) {
        VaultPaperTrading vaultLog = new VaultPaperTrading();
        return address(vaultLog);
    }
}
