/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../../AssetRegistry/MainRegistry.sol";
import "../../../Liquidator.sol";
import "../../TokenShop.sol";

contract DeployContractsTwo {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployMainReg(MainRegistry.NumeraireInformation calldata a)
        external
        returns (address)
    {
        MainRegistry main = new MainRegistry(a);
        main.transferOwnership(msg.sender);
        return address(main);
    }

    function deployLiquidator(address a, address b) external returns (address) {
        Liquidator liq = new Liquidator(a, b);
        liq.transferOwnership(msg.sender);
        return address(liq);
    }

    function deployTokenShop(address a) external returns (address) {
        TokenShop ts = new TokenShop(a);
        ts.transferOwnership(msg.sender);
        return address(ts);
    }
}
