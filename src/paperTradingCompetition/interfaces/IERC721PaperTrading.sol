// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../../interfaces/IERC721.sol";

interface IERC721PaperTrading is IERC721 {
    function mint(address to, uint256 id) external;

    function burn(uint256 id) external;

    function setApprovalForAll(address operator, bool approved) external;
}
