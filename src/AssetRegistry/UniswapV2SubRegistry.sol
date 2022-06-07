// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import {FixedPointMathLib} from '../utils/FixedPointMathLib.sol';

/** 
  * @title Sub-registry for Uniswap V2 LP tokens
  * @author Arcadia Finance
  * @notice The UniswapV2SubRegistry stores pricing logic and basic information for Uniswap V2 LP tokens
  * @dev No end-user should directly interact with the UniswapV2SubRegistry, only the Main-registry, Oracle-Hub or the contract owner
  * @dev Modifications from https://github.com/Uniswap/v2-periphery/blob/267ba44471f3357071a2fe2573fe4da42d5ad969/contracts/libraries/UniswapV2LiquidityMathLibrary.sol
 */
contract UniswapV2SubRegistry is SubRegistry {
  using FixedPointMathLib for uint256;

  uint256 public constant poolUnit = 1000000000000000000; //All Uniswap V2 pair-tokens have 18 decimals
  address public immutable uniswapV2Factory;

  struct AssetInformation {
    uint64 token0Unit;
    uint64 token1Unit;
    address pair;
    address token0;
    address token1;
  }

  mapping (address => AssetInformation) public assetToInformation;

  /**
   * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
   * @param _mainRegistry The address of the Main-registry
   * @param _oracleHub The address of the Oracle-Hub 
   * @param _uniswapV2Factory The factory for Uniswap V2 pairs
   */
  constructor (address _mainRegistry, address _oracleHub, address _uniswapV2Factory) SubRegistry(_mainRegistry, _oracleHub) {
      uniswapV2Factory = _uniswapV2Factory;
  }

  /**
   * @notice Returns the value of a certain asset, denominated in a given Numeraire
   * @param getValueInput A Struct with all the information neccessary to get the value of an asset
   * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
   * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
   */
  function getValue(GetValueInput memory getValueInput) public view override returns (uint256 valueInUsd, uint256 valueInNumeraire) {

    address[] memory tokens = new address[](2);
    tokens[0] = assetToInformation[getValueInput.assetAddress].token0;
    tokens[1] = assetToInformation[getValueInput.assetAddress].token1;
    uint256[] memory tokenAmounts = new uint256[](2);
    //To calculate the liquidity value after arbitrage, what matters is the ratio of the price of token0 compared to the price token1
    //Hence we need to use the true price for an equal amount of tokens, we use 1 WAD (10**18) to guarantee precision
    tokenAmounts[0] = FixedPointMathLib.WAD;
    tokenAmounts[1] = FixedPointMathLib.WAD;

    uint256[] memory tokenRates = IMainRegistry(oracleHub).getListOfValuesPerAsset(tokens, new uint256[](2), tokenAmounts, getValueInput.numeraire);

    (uint256 tokenAAmount) = getLiquidityValueAfterArbitrageToPrice(assetToInformation[getValueInput.assetAddress].pair, tokenRates[0], tokenRates[1], getValueInput.assetAmount);
    //Since Uniswap V2 uses 50/50 pools, it is sufficient to calculate the value of token 0 and multiply with 2 to get the total value of the liquidity position
    //The token rate is 
    valueInNumeraire = 2 * FixedPointMathLib.mulDivDown(tokenAAmount, tokenRates[0], FixedPointMathLib.WAD);

    return(0, valueInNumeraire);
  }

    // computes the direction and magnitude of the profit-maximizing trade
    function computeProfitMaximizingTrade(
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 reserveA,
        uint256 reserveB
    ) pure internal returns (bool aToB, uint256 amountIn) {
        aToB = reserveA.mulDivDown(truePriceTokenB, reserveB) < truePriceTokenA;

        uint256 invariant = reserveA * reserveB;

        uint256 leftSide = FixedPointMathLib.sqrt(
            invariant * (aToB ? truePriceTokenA : truePriceTokenB) * 1000 /
            uint256(aToB ? truePriceTokenB : truePriceTokenA) * 997
        );
        uint256 rightSide = (aToB ? reserveA * 1000 : reserveB * 1000) / 997;

        if (leftSide < rightSide) return (false, 0);

        // compute the amount that must be sent to move the price to the profit-maximizing price
        amountIn = leftSide - rightSide;
    }

    // gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given an externally observed true price
    function getReservesAfterArbitrage(
        address pair,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB
    ) view internal returns (uint256 reserveA, uint256 reserveB) {
        // first get reserves before the swap
        (reserveA, reserveB, ) = IUniswapV2Pair(pair).getReserves();

        require(reserveA > 0 && reserveB > 0, 'UniswapV2ArbitrageLibrary: ZERO_PAIR_RESERVES');

        // then compute how much to swap to arb to the true price
        (bool aToB, uint256 amountIn) = computeProfitMaximizingTrade(truePriceTokenA, truePriceTokenB, reserveA, reserveB);

        if (amountIn == 0) {
            return (reserveA, reserveB);
        }

        // now affect the trade to the reserves
        if (aToB) {
            uint amountOut = getAmountOut(amountIn, reserveA, reserveB);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            uint amountOut = getAmountOut(amountIn, reserveB, reserveA);
            reserveB += amountIn;
            reserveA -= amountOut;
        }
    }

    // computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 reservesA,
        uint256 reservesB,
        uint256 totalSupply,
        uint256 liquidityAmount,
        bool feeOn,
        uint kLast
    ) internal pure returns (uint256 tokenAAmount) {
        if (feeOn && kLast > 0) {
            uint rootK = FixedPointMathLib.sqrt(reservesA * reservesB);
            uint rootKLast = FixedPointMathLib.sqrt(kLast);
            if (rootK > rootKLast) {
                uint numerator = totalSupply * (rootK - rootKLast);
                uint denominator = rootK * 5 + rootKLast;
                uint feeLiquidity = numerator / denominator;
                totalSupply = totalSupply + feeLiquidity;
            }
        }
        return (reservesA * liquidityAmount / totalSupply);
    }

    // given two tokens, tokenA and tokenB, and their "true price", i.e. the observed ratio of value of token A to token B,
    // and a liquidity amount, returns the value of the liquidity in terms of tokenA and tokenB
    function getLiquidityValueAfterArbitrageToPrice(
        address pair,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 liquidityAmount
    ) internal view returns (
        uint256 tokenAAmount
    ) {
        bool feeOn = IUniswapV2Factory(uniswapV2Factory).feeTo() != address(0);
        uint kLast = feeOn ? IUniswapV2Pair(pair).kLast() : 0;
        uint totalSupply = IUniswapV2Pair(pair).totalSupply();

        // this also checks that totalSupply > 0
        require(totalSupply >= liquidityAmount && liquidityAmount > 0, 'ComputeLiquidityValue: LIQUIDITY_AMOUNT');

        (uint reservesA, uint reservesB) = getReservesAfterArbitrage(pair, truePriceTokenA, truePriceTokenB);

        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

}