// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "../../lib/solmate/src/mixins/ERC4626.sol";

contract MockERC4626 is ERC4626 {
    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol
    ) ERC4626(_underlying, _name, _symbol) {}

    function totalAssets() public view override returns (uint256) {
        return ERC20(asset).balanceOf(address(this));
    }

}
