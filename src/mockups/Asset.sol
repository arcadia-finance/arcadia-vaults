/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/solmate/src/tokens/ERC20.sol";

contract Asset is ERC20 {
    constructor(string memory name, string memory symbol, uint8 _decimalsInput) ERC20(name, symbol, _decimalsInput) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
