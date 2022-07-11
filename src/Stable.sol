/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0;

import "./mockups/ERC20SolmateMock.sol";
import "./interfaces/IFactory.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Stable is ERC20, Ownable {
    address public liquidator;
    address public factory;

    modifier onlyVault() {
        require(
            IFactory(factory).isVault(msg.sender),
            "Only a vault can mint!"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimalsInput,
        address liquidatorAddress,
        address _factory
    ) ERC20(name, symbol, _decimalsInput) {
        liquidator = liquidatorAddress;
        factory = _factory;
    }

    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    function mint(address to, uint256 amount) public virtual onlyVault {
        _mint(to, amount);
    }

    function setLiquidator(address liq) public onlyOwner {
        liquidator = liq;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function safeBurn(address from, uint256 amount) public returns (bool) {
        require(msg.sender == from || msg.sender == liquidator);
        _burn(from, amount);

        return true;
    }
}
