/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../Stable.sol";

contract StablePaperTrading is Stable {
    address public tokenShop;

    modifier onlyVaultOrShop() {
        require(
            IFactory(factory).isVault(msg.sender) || msg.sender == tokenShop,
            "Only a vault or tokenShop can mint!"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimalsInput,
        address liquidatorAddress,
        address _factory
    ) Stable(name, symbol, _decimalsInput, liquidatorAddress, _factory) {}

    function setTokenShop(address _tokenShop) public onlyOwner {
        tokenShop = _tokenShop;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (from == to) {
            return true;
        } else {
            return super.transferFrom(from, to, amount);
        }
    }

    function mint(address to, uint256 amount) public override onlyVaultOrShop {
        _mint(to, amount);
    }
}
