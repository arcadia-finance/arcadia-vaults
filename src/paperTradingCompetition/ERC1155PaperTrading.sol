// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../mockups/ERC1155SolmateMock.sol";

contract ERC1155PaperTrading is ERC1155Mock {
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
        address _tokenShop
    ) ERC1155Mock(name, symbol) {
        tokenShop = _tokenShop;
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public override onlyTokenShop {
        _mint(to, id, amount, "");
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
    }
}
