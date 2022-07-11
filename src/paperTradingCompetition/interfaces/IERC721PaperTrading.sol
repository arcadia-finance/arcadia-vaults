/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: AGPL-3.0-or-later
 */
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IERC721.sol";

interface IERC721PaperTrading is IERC721 {
    function mint(address to, uint256 id) external;

    function burn(uint256 id) external;

    function setApprovalForAll(address operator, bool approved) external;
}
