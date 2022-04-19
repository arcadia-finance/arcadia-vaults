// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../lib/solmate/src/tokens/ERC721.sol";

contract ERC721NoApprove is ERC721 {

    constructor() ERC721("ERC721 No Appr", "721NOAP") {}

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(from == ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        // require(
        //     msg.sender == from || msg.sender == getApproved[id] || isApprovedForAll[from][msg.sender],
        //     "NOT_AUTHORIZED"
        // );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            balanceOf[from]--;

            balanceOf[to]++;
        }

        ownerOf[id] = to;

        //delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "ok";
    }
}