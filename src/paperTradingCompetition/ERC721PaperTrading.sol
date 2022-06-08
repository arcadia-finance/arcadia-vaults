// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../mockups/ERC721SolmateMock.sol";

contract ERC721PaperTrading is ERC721Mock {
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
    ) ERC721Mock(name, symbol) {
        tokenShop = _tokenShop;
    }

    function mint(address to, uint256 id) public override onlyTokenShop {
        _mint(to, id);
    }

    function burn(uint256 id) public {
        require(msg.sender == ownerOf[id], "You are not the owner");
        _burn(id);
    }
}
