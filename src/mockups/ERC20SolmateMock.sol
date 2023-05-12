// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../lib/solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimalsInput_)
        ERC20(name_, symbol_, decimalsInput_)
    { }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
