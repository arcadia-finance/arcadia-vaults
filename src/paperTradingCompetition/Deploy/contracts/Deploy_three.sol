/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../ERC20PaperTrading.sol";
import "../../ERC721PaperTrading.sol";
import "../../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../../AssetRegistry/FloorERC721SubRegistry.sol";
import "../../../OracleHub.sol";

contract DeployContractsThree {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployERC20(
        string calldata a,
        string calldata b,
        uint8 c,
        address d
    ) external returns (address) {
        ERC20PaperTrading erc20 = new ERC20PaperTrading(a, b, c, d);
        return address(erc20);
    }

    function deployERC721(
        string calldata a,
        string calldata b,
        address c
    ) external returns (address) {
        ERC721PaperTrading erc721 = new ERC721PaperTrading(a, b, c);
        return address(erc721);
    }

    function deployOracHub() external returns (address) {
        OracleHub orachub = new OracleHub();
        orachub.transferOwnership(msg.sender);
        return address(orachub);
    }

    function deployERC20SubReg(address a, address b)
        external
        returns (address)
    {
        StandardERC20Registry erc20Reg = new StandardERC20Registry(a, b);
        erc20Reg.transferOwnership(msg.sender);
        return address(erc20Reg);
    }

    function deployERC721SubReg(address a, address b)
        external
        returns (address)
    {
        FloorERC721SubRegistry erc721Reg = new FloorERC721SubRegistry(a, b);
        erc721Reg.transferOwnership(msg.sender);
        return address(erc721Reg);
    }
}
