/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./UniswapV2PairMock.sol";
import "../interfaces/IUniswapV2Pair.sol";

contract UniswapV2FactoryMock {
    address public feeTo;
    address public owner;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPair(address token0, address token1) external returns (address pair) {
        require(token0 != token1, "UniswapV2: IDENTICAL_ADDRESSES");
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(token1 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS");
        require(getPair[token1][token0] == address(0), "UniswapV2: PAIR_EXISTS");
        bytes memory bytecode = type(UniswapV2PairMock).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == owner, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }
}
