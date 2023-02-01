// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// interfaces
import "../../lib/solmate/src/tokens/ERC20.sol";

contract ATokenMock is ERC20 {
    address public uToken;

    constructor(address uToken_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_, decimals_)
    {
        uToken = uToken_;
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return uToken;
    }
}
