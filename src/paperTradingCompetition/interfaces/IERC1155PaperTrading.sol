/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IERC1155.sol";

interface IERC1155PaperTrading is IERC1155 {
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external;

    function burn(uint256 id, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;
}
