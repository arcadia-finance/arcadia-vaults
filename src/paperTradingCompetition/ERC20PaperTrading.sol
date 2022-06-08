// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../mockups/ERC20SolmateMock.sol";

contract ERC20PaperTrading is ERC20Mock {
    address public tokenShop;

    /**
     * @dev Throws if called by any address other than the tokenshop
     *  only added for the paper trading competition
     */
    modifier onlyTokenShop() {
        require(msg.sender == tokenShop, "Not tokenshop");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimalsInput,
        address _tokenShop
    ) ERC20Mock(name, symbol, _decimalsInput) {
        tokenShop = _tokenShop;
    }

    function mint(address to, uint256 amount) public override onlyTokenShop {
        _mint(to, amount);
    }
}
