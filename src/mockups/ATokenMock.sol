// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

// interfaces
import "../../lib/solmate/src/tokens/ERC20.sol";
import "../interfaces/IAToken.sol";

contract ATokenMock is ERC20 {
    address public uToken;

    constructor(
        address _uToken,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol, ERC20(_uToken).decimals()) {
        uToken = _uToken;
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return uToken;
    }
}