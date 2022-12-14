/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import "./AbstractPricingModule.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import {PRBMath} from "../utils/PRBMath.sol";

/**
 * @title Pricing-Module for Uniswap V2 LP tokens
 * @author Arcadia Finance
 * @notice The UniswapV2PricingModule stores pricing logic and basic information for Uniswap V2 LP tokens
 * @dev No end-user should directly interact with the UniswapV2PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 * @dev Most logic in this contract is a modifications of
 *      https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
 */
contract UniswapV2PricingModule is PricingModule {
    using FixedPointMathLib for uint256;
    using PRBMath for uint256;

    uint256 public constant poolUnit = 1000000000000000000;
    address public immutable uniswapV2Factory;
    address public immutable erc20PricingModule;

    bool public feeOn;

    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        address token0;
        address token1;
        address assetAddress;
        uint16[] assetCollateralFactors;
        uint16[] assetLiquidationThresholds;
    }

    /**
     * @notice A Pricing-Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param _mainRegistry The address of the Main-registry
     * @param _oracleHub The address of the Oracle-Hub
     * @param _uniswapV2Factory The factory for Uniswap V2 pairs
     */
    constructor(address _mainRegistry, address _oracleHub, address _uniswapV2Factory, address _erc20PricingModule)
        PricingModule(_mainRegistry, _oracleHub)
    {
        uniswapV2Factory = _uniswapV2Factory;
        erc20PricingModule = _erc20PricingModule;
    }

    /*///////////////////////////////////////////////////////////////
                        UNISWAP V2 FEE
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches boolean on the uniswap factory if fees are enabled or not
     */
    function syncFee() external {
        feeOn = IUniswapV2Factory(uniswapV2Factory).feeTo() != address(0);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the UniswapV2PricingModule, or overwrites an existing asset.
     * @param assetInformation A Struct with information about the asset
     * - token0: The first token in the Uni pair
     * - token1: The second token in the Uni pair
     * - assetCollateralFactors: The List of collateral factors for the asset for the different BaseCurrencies
     * - assetLiquidationThresholds: The List of liquidation thresholds for the asset for the different BaseCurrencies
     * @dev The list of Risk Variables (Collateral Factor and Liquidation Threshold) should either be as long as
     * the number of baseCurrencies added to the Main Registry,or the list must have length 0.
     * If the list has length zero, the risk variables of the baseCurrency for all assets
     * is initiated as default (safest lowest rating).
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added/overwritten in the Main-Registry as well.
     *      By overwriting existing assets, the contract owner can temper with the value of assets already used as collateral
     *      (for instance by changing the oracle address to a fake price feed) and poses a security risk towards protocol users.
     *      This risk can be mitigated by setting the boolean "assetsUpdatable" in the MainRegistry to false, after which
     *      assets are no longer updatable.
     */
    function setAssetInformation(AssetInformation memory assetInformation) external onlyOwner {
        address assetAddress = assetInformation.assetAddress;

        assetInformation.token0 = IUniswapV2Pair(assetAddress).token0();
        assetInformation.token1 = IUniswapV2Pair(assetAddress).token1();

        address[] memory tokens = new address[](2);
        tokens[0] = assetInformation.token0;
        tokens[1] = assetInformation.token1;

        require(IMainRegistry(mainRegistry).batchIsWhiteListed(tokens, new uint256[](2)), "PMUV2_SAI: NOT_WHITELISTED");

        if (!inPricingModule[assetAddress]) {
            inPricingModule[assetAddress] = true;
            assetsInPricingModule.push(assetAddress);
        }

        assetToInformation[assetAddress].token0 = assetInformation.token0;
        assetToInformation[assetAddress].token1 = assetInformation.token1;
        assetToInformation[assetAddress].assetAddress = assetAddress;
        _setRiskVariables(
            assetAddress, assetInformation.assetCollateralFactors, assetInformation.assetLiquidationThresholds
        );

        isAssetAddressWhiteListed[assetAddress] = true;

        require(IMainRegistry(mainRegistry).addAsset(assetAddress), "PMUV2_SAI: Unable to add in MR");
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param assetAddress The address of the asset
     * @dev Since Uniswap V2 LP tokens (ERC20) have no Id, the Id should be set to 0
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isWhiteListed(address assetAddress, uint256) external view override returns (bool) {
        if (isAssetAddressWhiteListed[assetAddress]) {
            return true;
        }

        return false;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a Uniswap V2 LP-token
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the LP-token
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of tokens, ERC20 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency (base-asset) in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return valueInBaseCurrency The value of the asset denominated in BaseCurrency different from USD with 18 Decimals precision
     * @dev trustedUsdPriceToken cannot realisticly overflow, requires unit price of a token with 0 decimals (worst case),
     * to be bigger than $1,16 * 10^41
     * @dev The UniswapV2PricingModule will always return the value in valueInUsd,
     * valueInBaseCurrency will always be 0
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no explicit check is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 valueInBaseCurrency, uint256 collFactor, uint256 liqThreshold)
    {
        // To calculate the liquidity value after arbitrage, what matters is the ratio of the price of token0 compared to the price of token1
        // Hence we need to use a trusted external price for an equal amount of tokens,
        // we use for both tokens the USD price of 1 WAD (10**18) to guarantee precision.
        (uint256 trustedUsdPriceToken0,,,) = PricingModule(erc20PricingModule).getValue(
            GetValueInput({
                assetAddress: assetToInformation[getValueInput.assetAddress].token0,
                assetId: 0,
                assetAmount: FixedPointMathLib.WAD,
                baseCurrency: 0
            })
        );
        (uint256 trustedUsdPriceToken1,,,) = PricingModule(erc20PricingModule).getValue(
            GetValueInput({
                assetAddress: assetToInformation[getValueInput.assetAddress].token1,
                assetId: 0,
                assetAmount: FixedPointMathLib.WAD,
                baseCurrency: 0
            })
        );

        //
        (uint256 token0Amount, uint256 token1Amount) = _getTrustedTokenAmounts(
            getValueInput.assetAddress, trustedUsdPriceToken0, trustedUsdPriceToken1, getValueInput.assetAmount
        );
        // trustedUsdPriceToken0 is the value of token0 in USD with 18 decimals precision for 1 WAD of tokens,
        // we need to recalculate to find the value of the actual amount of underlying token0 in the liquidity position.
        valueInUsd = FixedPointMathLib.mulDivDown(token0Amount, trustedUsdPriceToken0, FixedPointMathLib.WAD)
            + FixedPointMathLib.mulDivDown(token1Amount, trustedUsdPriceToken1, FixedPointMathLib.WAD);

        collFactor = assetRiskVars[getValueInput.assetAddress].assetCollateralFactors[getValueInput.baseCurrency];
        liqThreshold =
            assetRiskVars[getValueInput.assetAddress].assetLiquidationThresholds[getValueInput.baseCurrency];

        return (valueInUsd, 0, collFactor, liqThreshold);
    }

    /**
     * @notice Returns the trusted amount of token0 provided as liquidity, given two trusted prices of token0 and token1
     * @param pair Address of the Uniswap V2 Liquidity pool
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given BaseCurrency
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given BaseCurrency
     * @param liquidityAmount The amount of LP tokens (ERC20)
     * @return token0Amount The trusted amount of token0 provided as liquidity
     * @return token1Amount The trusted amount of token1 provided as liquidity
     * @dev Both trusted prices must be for the same BaseCurrency, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev The trusted amount of liquidity is calculated by first bringing the liquidity pool in equilibrium,
     *      by calculating what the reserves of the pool would be if a profit-maximizing trade is done.
     *      As such flash-loan attacks are mitigated, where an attacker swaps a large amount of the higher priced token,
     *      to bring the pool out of equilibrium, resulting in liquidity postitions with a higher share of the most valuable token.
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function _getTrustedTokenAmounts(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) internal view returns (uint256 token0Amount, uint256 token1Amount) {
        uint256 kLast = feeOn ? IUniswapV2Pair(pair).kLast() : 0;
        uint256 totalSupply = IUniswapV2Pair(pair).totalSupply();

        // this also checks that totalSupply > 0
        require(totalSupply >= liquidityAmount && liquidityAmount > 0, "UV2_GTTA: LIQUIDITY_AMOUNT");

        (uint256 reserve0, uint256 reserve1) = _getTrustedReserves(pair, trustedPriceToken0, trustedPriceToken1);

        return _computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
    }

    /**
     * @notice Gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given externally observed trusted price
     * @param pair Address of the Uniswap V2 Liquidity pool
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given BaseCurrency
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given BaseCurrency
     * @return reserve0 The reserves of token0 in the liquidity pool after arbitrage
     * @return reserve1 The reserves of token1 in the liquidity pool after arbitrage
     * @dev Both trusted prices must be for the same BaseCurrency, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function _getTrustedReserves(address pair, uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        internal
        view
        returns (uint256 reserve0, uint256 reserve1)
    {
        // The untrusted reserves from the pair, these can be manipulated!!!
        (reserve0, reserve1,) = IUniswapV2Pair(pair).getReserves();

        require(reserve0 > 0 && reserve1 > 0, "UV2_GTR: ZERO_PAIR_RESERVES");

        // Compute how much to swap to balance the pool with externally observed trusted prices
        (bool token0ToToken1, uint256 amountIn) =
            _computeProfitMaximizingTrade(trustedPriceToken0, trustedPriceToken1, reserve0, reserve1);

        // Pool is balanced -> no need to affect the reserves
        if (amountIn == 0) {
            return (reserve0, reserve1);
        }

        // Pool is unbalanced -> Apply the profit maximalising trade to the reserves
        if (token0ToToken1) {
            uint256 amountOut = _getAmountOut(amountIn, reserve0, reserve1);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            uint256 amountOut = _getAmountOut(amountIn, reserve1, reserve0);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
    }

    /**
     * @notice Computes the direction and magnitude of the profit-maximizing trade
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given BaseCurrency
     * @param trustedPriceToken1 Trusted price of an equalamount of Token1 in a given BaseCurrency
     * @param reserve0 The current untrusted reserves of token0 in the liquidity pool
     * @param reserve1 The current untrusted reserves of token1 in the liquidity pool
     * @return token0ToToken1 The direction of the profit-maximizing trade
     * @return amountIn The amount of tokens to be swapped of the profit-maximizing trade
     * @dev Both trusted prices must be for the same BaseCurrency, and for an equal amount of tokens
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
     * @dev Function overflows (and reverts) if reserve0 * trustedPriceToken0 > max uint256, however this is not possible in realistic scenario's
     *      This can only happen if trustedPriceToken0 is bigger than 2.23 * 10^43
     *      (for an asset with 0 decimals and reserve0 Max uint112 this would require a unit price of $2.23 * 10^7
     */
    function _computeProfitMaximizingTrade(
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (bool token0ToToken1, uint256 amountIn) {
        token0ToToken1 = FixedPointMathLib.mulDivDown(reserve0, trustedPriceToken0, reserve1) < trustedPriceToken1;

        uint256 invariant;
        unchecked {
            invariant = reserve0 * reserve1 * 1000; //Can never overflow: uint112 * uint112 * 1000
        }

        uint256 leftSide = FixedPointMathLib.sqrt(
            PRBMath.mulDiv(
                invariant,
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
     * @notice Computes the underlying token amounts of a LP-position
     * @param reserve0 The trusted reserves of token0 in the liquidity pool
     * @param reserve1 The trusted reserves of token1 in the liquidity pool
     * @param totalSupply The total supply of LP tokens (ERC20)
     * @param liquidityAmount The amount of LP tokens (ERC20)
     * @param kLast The product of the reserves as of the most recent liquidity event (0 if feeOn is false)
     * @return token0Amount The amount of token0 provided as liquidity
     * @return token1Amount The amount of token1 provided as liquidity
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function _computeTokenAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 kLast
    ) internal view returns (uint256 token0Amount, uint256 token1Amount) {
        if (feeOn && kLast > 0) {
            uint256 rootK = FixedPointMathLib.sqrt(reserve0 * reserve1);
            uint256 rootKLast = FixedPointMathLib.sqrt(kLast);
            if (rootK > rootKLast) {
                uint256 numerator = totalSupply * (rootK - rootKLast);
                uint256 denominator = rootK * 5 + rootKLast;
                uint256 feeLiquidity = numerator / denominator;
                totalSupply = totalSupply + feeLiquidity;
            }
        }
        token0Amount = FixedPointMathLib.mulDivDown(reserve0, liquidityAmount, totalSupply);
        token1Amount = FixedPointMathLib.mulDivDown(reserve1, liquidityAmount, totalSupply);
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
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
