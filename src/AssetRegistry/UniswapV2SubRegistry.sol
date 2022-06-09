/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialization, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractSubRegistry.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

/**
 * @title Sub-registry for Uniswap V2 LP tokens
 * @author Arcadia Finance
 * @notice The UniswapV2SubRegistry stores pricing logic and basic information for Uniswap V2 LP tokens
 * @dev No end-user should directly interact with the UniswapV2SubRegistry, only the Main-registry, Oracle-Hub or the contract owner
 * @dev Most logic in this contract is a modifications of 
 *      https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
 */
contract UniswapV2SubRegistry is SubRegistry {
    using FixedPointMathLib for uint256;

    uint256 public constant poolUnit = 1000000000000000000;
    address public immutable uniswapV2Factory;

    bool feeOn;

    struct AssetInformation {
        address token0;
        address token1;
    }

    mapping(address => AssetInformation) public assetToInformation;

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param _mainRegistry The address of the Main-registry
     * @param _oracleHub The address of the Oracle-Hub 
     * @param _uniswapV2Factory The factory for Uniswap V2 pairs
     */
    constructor(
        address _mainRegistry,
        address _oracleHub,
        address _uniswapV2Factory
    ) SubRegistry(_mainRegistry, _oracleHub) {
        uniswapV2Factory = _uniswapV2Factory;
    }

    /**
     * @notice Fetches boolean on the uniswap factory if fees are enabled or not
     */
    function syncFee() external {
        feeOn = IUniswapV2Factory(uniswapV2Factory).feeTo() != address(0);
    }

    /**
     * @notice Adds a new asset to the UniswapV2SubRegistry, or overwrites an existing asset.
     * @param assetAddress Contract address of the Uniswap V2 Liquidity pair
     * @param assetCreditRatings The List of Credit Ratings for the asset for the different Numeraires.
     * @dev The list of Credit Ratings should or be as long as the number of numeraires added to the Main Registry,
     *      or the list must have length 0. If the list has length zero, the credit ratings of the asset for all numeraires
     *      is initiated as credit rating with index 0 by default (worst credit rating).
     * @dev The assets are added/overwritten in the Main-Registry as well.
     *      By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracleaddres to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     */
    function setAssetInformation(
        address assetAddress,
        uint256[] calldata assetCreditRatings
    ) external onlyOwner {
        AssetInformation memory assetInformation;

        assetInformation.token0 = IUniswapV2Pair(assetAddress).token0();
        assetInformation.token1 = IUniswapV2Pair(assetAddress).token1();

        address[] memory tokens = new address[](2);
        tokens[0] = assetInformation.token0;
        tokens[1] = assetInformation.token1;

        require(IMainRegistry(mainRegistry).batchIsWhiteListed(tokens, new uint256[](2)), "UV2_SAI: NOT_WHITELISTED");

        if (!inSubRegistry[assetAddress]) {
            inSubRegistry[assetAddress] = true;
            assetsInSubRegistry.push(assetAddress);
        }

        assetToInformation[assetAddress] = assetInformation;
        isAssetAddressWhiteListed[assetAddress] = true;
        IMainRegistry(mainRegistry).addAsset(assetAddress, assetCreditRatings);
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since Uniswap V2 LP tokens (ERC20) have no Id, the Id should be set to 0
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256)
        external
        view
        override
        returns (bool)
    {
        if (isAssetAddressWhiteListed[assetAddress]) {
            return true;
        }

        return false;
    }

    /**
     * @notice Returns the value of a certain asset, denominated in a given Numeraire
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInNumeraire The value of the asset denominated in Numeraire different from USD with 18 Decimals precision
     * @dev Since Uniswap V2 uses 50/50 pools, it is sufficient to only calculate the value of one of the underlying tokens of the 
     *      liquidity position and multiply with 2 to get the total value of the liquidity position
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (
            uint256 valueInUsd,
            uint256 valueInNumeraire
        )
    {
        address[] memory tokens = new address[](2);
        tokens[0] = assetToInformation[getValueInput.assetAddress].token0;
        tokens[1] = assetToInformation[getValueInput.assetAddress].token1;
        uint256[] memory tokenAmounts = new uint256[](2);
        // To calculate the liquidity value after arbitrage, what matters is the ratio of the price of token0 compared to the price of token1
        // Hence we need to use the true price for an equal amount of tokens, we use 1 WAD (10**18) to guarantee precision
        tokenAmounts[0] = FixedPointMathLib.WAD;
        tokenAmounts[1] = FixedPointMathLib.WAD;

        uint256[] memory tokenRates = IMainRegistry(mainRegistry).getListOfValuesPerAsset(tokens, new uint256[](2), tokenAmounts, getValueInput.numeraire);

        uint256 token0Amount = getLiquidityValueAfterArbitrageToPrice(getValueInput.assetAddress, tokenRates[0], tokenRates[1], getValueInput.assetAmount);
        // Since Uniswap V2 uses 50/50 pools, it is sufficient to calculate the value of token 0 and multiply with 2 to get the total value of the liquidity position.
        // tokenRates[0] is the value of token0 in a given Numeraire for 1 WAD of tokens, we need to recalculate to find the value
        // of the actual amount of underlying token0 in the liquidity position.
        valueInNumeraire = 2 * FixedPointMathLib.mulDivDown(token0Amount, tokenRates[0], FixedPointMathLib.WAD);

        return(0, valueInNumeraire);
    }

    /**
     * @notice Returns the trusted amount of token0 provided as liquidity, given two trusted prices of token0 and token1
     * @param pair Address of the Uniswap V2 Liquidity pool
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given Numeraire
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given Numeraire
     * @param liquidityAmount The amount of LP tokens (ERC20)
     * @return token0Amount The trusted amount of token0 provided as liquidity
     * @dev Both trusted prices must be for the same Numeraire, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev The trusted amount of liquidity is calculated by first bringing the liquidity pool in equilibrium,
     *      by calculating what the reserves of the pool would be if a profit-maximizing trade is done.
     *      As such flash-loan attacks are mitigated, where an attacker swaps a large amount of the higher priced token,
     *      to bring the pool out of equilibrium, resulting in liquidity postitions with a higher share of expensive token.
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function getLiquidityValueAfterArbitrageToPrice(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) internal view returns (uint256 token0Amount) {
        uint kLast = feeOn ? IUniswapV2Pair(pair).kLast() : 0;
        uint totalSupply = IUniswapV2Pair(pair).totalSupply();

        // this also checks that totalSupply > 0
        require(totalSupply >= liquidityAmount && liquidityAmount > 0, 'UV2_GV: LIQUIDITY_AMOUNT');

        (uint reserve0, uint reserve1) = getReservesAfterArbitrage(pair, trustedPriceToken0, trustedPriceToken1);

        return computeLiquidityValue(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
    }

    /**
     * @notice Gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given externally observed trusted price
     * @param pair Address of the Uniswap V2 Liquidity pool
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given Numeraire
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given Numeraire
     * @return reserve0 The reserves of token0 in the liquidity pool after arbitrage
     * @return reserve1 The reserves of token1 in the liquidity pool after arbitrage
     * @dev Both trusted prices must be for the same Numeraire, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function getReservesAfterArbitrage(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1
    ) internal view returns (uint256 reserve0, uint256 reserve1) {
        // first get reserves before the swap
        (reserve0, reserve1, ) = IUniswapV2Pair(pair).getReserves();

        require(reserve0 > 0 && reserve1 > 0, 'UV2_GV: ZERO_PAIR_RESERVES');

        // then compute how much to swap to arb to the true price
        (bool token0ToToken1, uint256 amountIn) = computeProfitMaximizingTrade(trustedPriceToken0, trustedPriceToken1, reserve0, reserve1);

        if (amountIn == 0) {
            return (reserve0, reserve1);
        }

        // now affect the trade to the reserves
        if (token0ToToken1) {
            uint amountOut = getAmountOut(amountIn, reserve0, reserve1);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            uint amountOut = getAmountOut(amountIn, reserve1, reserve0);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
    }

    /**
     * @notice Computes the direction and magnitude of the profit-maximizing trade
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given Numeraire
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given Numeraire
     * @param reserve0 The current reserves of token0 in the liquidity pool
     * @param reserve1 The current reserves of token1 in the liquidity pool
     * @return token0ToToken1 The direction of the profit-maximizing trade
     * @return amountIn The amount of tokens to be swapped of the profit-maximizing trade
     * @dev Both trusted prices must be for the same Numeraire, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     * @dev See https://arxiv.org/pdf/1911.03380.pdf for the derivation:
     *      - Maximise: trustedPriceTokenOut * amountOut - trustedPriceTokenIn * amountIn
     *      - Constraints:
     *            * amountIn > 0
     *            * amountOut > 0
     *            * Uniswap V2 AMM: (reserveIn + 997 * amountIn / 1000) * (reserveOut - amountOut) = reserveIn * reserveOut
     *      - Solution:
     *            * amountIn = sqrt[(1000 * reserveIn * amountOut * trustedPriceTokenOut) / (997 * trustedPriceTokenIn)] - 1000 * reserveIn / 997 (if a profit-maximizing trade exists)
     *            * amountIn = 0 (if a profit-maximizing trade does not exists)
     */
    function computeProfitMaximizingTrade(
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (bool token0ToToken1, uint256 amountIn) {
        token0ToToken1 = FixedPointMathLib.mulDivDown(reserve0, trustedPriceToken0, reserve1) < trustedPriceToken1;

        uint256 invariant = reserve0 * reserve1;

        uint256 leftSide = FixedPointMathLib.sqrt(
            FixedPointMathLib.mulDivDown(
                invariant * 1000,
                (token0ToToken1 ? trustedPriceToken1 : trustedPriceToken0),
                uint256(token0ToToken1 ? trustedPriceToken0 : trustedPriceToken1) * 997
            )
        );
        uint256 rightSide = (token0ToToken1 ? reserve0 * 1000 : reserve1 * 1000) / 997;

        if (leftSide < rightSide) return (false, 0);

        // compute the amount that must be sent to move the price to the profit-maximizing price
        amountIn = leftSide - rightSide;
    }

    /**
     * @notice Computes liquidity value of a LP-position given all the parameters of the pair
     * @param reserve0 The reserves of token0 in the liquidity pool
     * @param reserve1 The reserves of token1 in the liquidity pool
     * @param totalSupply The total supply of LP tokens (ERC20)
     * @param liquidityAmount The amount of LP tokens (ERC20)
     * @param kLast The product of the reserves as of the most recent liquidity event (0 if feeOn is false)
     * @return token0Amount The amount of token0 provided as liquidity
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function computeLiquidityValue(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 kLast
    ) internal view returns (uint256 token0Amount) {
        if (feeOn && kLast > 0) {
            uint rootK = FixedPointMathLib.sqrt(reserve0 * reserve1);
            uint rootKLast = FixedPointMathLib.sqrt(kLast);
            if (rootK > rootKLast) {
                uint numerator = totalSupply * (rootK - rootKLast);
                uint denominator = rootK * 5 + rootKLast;
                uint feeLiquidity = numerator / denominator;
                totalSupply = totalSupply + feeLiquidity;
            }
        }
        return FixedPointMathLib.mulDivDown(reserve0, liquidityAmount, totalSupply);
    }

    /**
     * @notice Given an input amount of an asset and pair reserves, computes the maximum output amount of the other asset
     * @param reserveIn The reserves of tokenIn in the liquidity pool
     * @param reserveOut The reserves of tokenOut in the liquidity pool
     * @param amountIn The input amount of tokenIn
     * @return amountOut The output amount of tokenIn
     * @dev Derived from Uniswap V2 AMM equation:
     *      (reserveIn + 997 * amountIn / 1000) * (reserveOut - amountOut) = reserveIn * reserveOut
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
