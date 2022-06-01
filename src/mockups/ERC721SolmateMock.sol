// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.6;

import "../utils/Strings.sol";

import "../../lib/solmate/src/tokens/ERC721.sol";

contract ERC721Mock is ERC721 {
    using Strings for uint256;

    string baseURI;
    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
    }

    function mint(address to, uint256 id) public virtual {
        _mint(to, id);
    }

    function setBaseUri(string calldata newBaseUri) external onlyOwner {
        baseURI = newBaseUri;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            ownerOf[tokenId] != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory currentBaseURI = baseURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
                : "";
    }
}
