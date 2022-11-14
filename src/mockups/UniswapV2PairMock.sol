/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity >=0.4.22 <0.9.0;

import "../../lib/solmate/src/tokens/ERC20.sol";
import "../interfaces/IUniswapV2Factory.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import "../../lib/forge-std/src/Test.sol";

contract UniswapV2PairMock is ERC20,Test {
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public kLast;

    constructor() ERC20("Uniswap V2", "UNI-V2", 18) {
        factory = msg.sender;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to, uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        bool feeOn = _mintFee();
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1 - MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = min(amount0 * _totalSupply / reserve0, amount1 * _totalSupply / reserve1);
        }
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        require(amount0 <= type(uint112).max - reserve0, "UniswapV2: OVERFLOW");
        require(amount1 <= type(uint112).max - reserve1, "UniswapV2: OVERFLOW");
        reserve0 = uint112(reserve0 + amount0);
        reserve1 = uint112(reserve1 + amount1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
    }

      function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                              // gas savings
        uint balance0 = ERC20(token0).balanceOf(address(this));
        uint balance1 = ERC20(token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        console.log("liquidity",liquidity);
        bool feeOn = _mintFee();
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        console.log("_totalSupply",_totalSupply);
        console.log("balance0b",balance0);
        console.log("balance1b",balance1);
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        console.log("amount0",amount0);
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        console.log("amount1",amount1);
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        console.log("to",to);
        ERC20(_token0).transfer(to, amount0);
        ERC20(_token1).transfer(to, amount1);
        balance0 = ERC20(_token0).balanceOf(address(this));
        balance1 = ERC20(_token1).balanceOf(address(this));
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function _mintFee() private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (!feeOn && _kLast != 0) {
            kLast = 0;
        }
    }

    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        bool feeOn = _mintFee();

        require(_reserve0 * _reserve1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        reserve0 = uint112(_reserve0);
        reserve1 = uint112(_reserve1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
    }

    function swapToken0ToToken1(uint256 amountIn) external returns (uint256 lpGrowth) {
        uint256 amountOut = getAmountOut(amountIn, reserve0, reserve1);
        require(amountOut < reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        lpGrowth = FixedPointMathLib.WAD * FixedPointMathLib.sqrt((reserve0 + amountIn) * (reserve1 - amountOut))
            / FixedPointMathLib.sqrt(uint256(reserve0) * uint256(reserve1));
        reserve0 = uint112(reserve0 + amountIn);
        reserve1 = uint112(reserve1 - amountOut);
    }

    function swapToken1ToToken0(uint256 amountIn) external returns (uint256 lpGrowth) {
        uint256 amountOut = getAmountOut(amountIn, reserve1, reserve0);
        require(amountOut < reserve0, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        lpGrowth = FixedPointMathLib.WAD * FixedPointMathLib.sqrt((reserve0 - amountOut) * (reserve1 + amountIn))
            / FixedPointMathLib.sqrt(uint256(reserve0) * uint256(reserve1));
        reserve0 = uint112(reserve0 - amountOut);
        reserve1 = uint112(reserve1 + amountIn);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
