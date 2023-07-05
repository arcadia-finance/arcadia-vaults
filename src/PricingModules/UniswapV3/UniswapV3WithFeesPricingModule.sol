/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { PricingModule, IPricingModule } from "../AbstractPricingModule.sol";
import { IMainRegistry } from "../interfaces/IMainRegistry.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { TickMath } from "./libraries/TickMath.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { PoolAddress } from "./libraries/PoolAddress.sol";
import { FixedPoint96 } from "./libraries/FixedPoint96.sol";
import { FixedPoint128 } from "./libraries/FixedPoint128.sol";
import { LiquidityAmounts } from "./libraries/LiquidityAmounts.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "lib/solmate/src/utils/SafeCastLib.sol";

/**
 * @title Pricing Module for Uniswap V3 Liquidity Positions.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Uniswap V3 Liquidity Positions.
 * @dev The UniswapV3PricingModule will not price the LP-tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 * @dev No end-user should directly interact with the UniswapV3PricingModule, only the Main-registry,
 * or the contract owner.
 */
contract UniswapV3WithFeesPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The maximum difference between the upper or lower tick and the current tick (from 0.2x to 5x the current price).
    // Calculated as: (sqrt(1.0001))log(sqrt(5)) = 16095.2
    int24 public constant MAX_TICK_DIFFERENCE = 16_095;

    // Map asset => uniswapV3Factory.
    mapping(address => address) public assetToV3Factory;

    // Map asset => id => positionInformation.
    mapping(address => mapping(uint256 => Position)) internal positions;

    // The Arcadia Pricing Module for standard ERC20 tokens (the underlying assets).
    PricingModule immutable erc20PricingModule;

    // Struct with information of a specific Liquidity Position.
    struct Position {
        uint96 exposureDelta0; // The total max exposure of token0 of the Liquidity Position at the time of deposit.
        address token0; // The contract address of the token0.
        uint96 exposureDelta1; // The total max exposure of token1 of the Liquidity Position at the time of deposit.
        address token1; // The contract address of the token1.
        uint128 liquidity; // The liquidity per tick of the Liquidity Position.
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param oracleHub_ The contract address of the OracleHub.
     * @param riskManager_ The address of the Risk Manager.
     * @param erc20PricingModule_ The contract address of the Pricing Module for ERC20s
     * @dev AssetType for Uniswap V3 Liquidity Positions (ERC721) is 1.
     */
    constructor(address mainRegistry_, address oracleHub_, address riskManager_, address erc20PricingModule_)
        PricingModule(mainRegistry_, oracleHub_, 1, riskManager_)
    {
        erc20PricingModule = PricingModule(erc20PricingModule_);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the UniswapV3PricingModule.
     * @param asset The contract address of the asset (also known as the NonfungiblePositionManager).
     * @dev Per protocol (eg. Uniswap V3 and its forks) there is a single asset,
     * and each Liquidity Position will have a different id.
     */
    function addAsset(address asset) external onlyOwner {
        require(!inPricingModule[asset], "PMUV3_AA: already added");

        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToV3Factory[asset] = INonfungiblePositionManager(asset).factory();

        // Will revert in MainRegistry if asset can't be added.
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /*///////////////////////////////////////////////////////////////
                            ALLOW LIST
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allow-listed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is whitelisted.
     */
    function isAllowListed(address asset, uint256 assetId) public view override returns (bool) {
        if (!inPricingModule[asset]) return false;

        try INonfungiblePositionManager(asset).positions(assetId) returns (
            uint96,
            address,
            address token0,
            address token1,
            uint24,
            int24,
            int24,
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        ) {
            return exposure[token0].maxExposure != 0 && exposure[token1].maxExposure != 0;
        } catch {
            return false;
        }
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a Uniswap V3 Liquidity Range.
     * @param getValueInput A Struct with the input variables (avoid stack too deep).
     * - asset: The contract address of the asset.
     * - assetId: The Id of the range.
     * - assetAmount: The amount of assets.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return valueInBaseCurrency The value of the asset denominated in a BaseCurrency different from USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @dev The UniswapV3PricingModule will always return the value denominated in USD.
     * @dev Uniswap Pools can be manipulated, we can't rely on the current price (or tick).
     * We use Chainlink oracles of the underlying assets to calculate the flashloan resistant price.
     */
    function getValue(IPricingModule.GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // Use variables as much as possible in local context, to avoid stack too deep errors.
        address asset = getValueInput.asset;
        uint256 id = getValueInput.assetId;
        uint256 baseCurrency = getValueInput.baseCurrency;
        address token0;
        address token1;
        uint256 usdPriceToken0;
        uint256 usdPriceToken1;
        uint256 principal0;
        uint256 principal1;
        {
            int24 tickLower;
            int24 tickUpper;
            uint128 liquidity;
            (token0, token1, tickLower, tickUpper, liquidity) = _getPosition(asset, id);

            // We use the USD price per 10^18 tokens instead of the USD price per token to guarantee
            // sufficient precision.
            (usdPriceToken0,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token0, assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
            );
            (usdPriceToken1,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token1, assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
            );

            // If the Usd price of one of the tokens is 0, the LP-token will also have a value of 0.
            if (usdPriceToken0 == 0 || usdPriceToken1 == 0) return (0, 0, 0, 0);

            // Calculate the amounts of the principal (the actual Liquidity Position).
            (principal0, principal1) = _getPrincipal(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
        }

        {
            // Calculate the amounts of the sum of tokensOwed and the accumulated fees.
            (uint256 tokensOwedAndFee0, uint256 tokensOwedAndFee1) = _getTokensOwedAndFees(asset, id);

            // Calculate the total value in USD, since the USD price is per 10^18 tokens we have to divide by 10^18.
            unchecked {
                valueInUsd = usdPriceToken0.mulDivDown(principal0 + tokensOwedAndFee0, 1e18)
                    + usdPriceToken1.mulDivDown(principal1 + tokensOwedAndFee1, 1e18);
            }
        }

        {
            // Fetch the risk variables of the underlying tokens for the given baseCurrency.
            (uint256 collateralFactor0, uint256 liquidationFactor0) =
                PricingModule(erc20PricingModule).getRiskVariables(token0, baseCurrency);
            (uint256 collateralFactor1, uint256 liquidationFactor1) =
                PricingModule(erc20PricingModule).getRiskVariables(token1, baseCurrency);

            // We take the most conservative (lowest) factor of both underlying assets.
            // If one token loses in value compared to the other token, Liquidity Providers will be relatively more exposed
            // to the asset that loses value. This is especially true for Uniswap V3: when the current tick is outside of the
            // liquidity range the LP is fully exposed to a single asset.
            collateralFactor = collateralFactor0 < collateralFactor1 ? collateralFactor0 : collateralFactor1;
            liquidationFactor = liquidationFactor0 < liquidationFactor1 ? liquidationFactor0 : liquidationFactor1;
        }

        return (valueInUsd, 0, collateralFactor, liquidationFactor);
    }

    /**
     * @notice Returns the information of the Liquidity Position.
     * @param asset The contract address of the Liquidity Position.
     * @param id The Id of the Liquidity Position.
     * @return token0 Token0 of the Liquidity Pool.
     * @return token1 Token1 of the Liquidity Pool.
     * @return tickLower The lower tick of the Liquidity Position.
     * @return tickUpper The upper tick of the Liquidity Position.
     * @return liquidity The liquidity per tick of the Liquidity Position.
     */
    function _getPosition(address asset, uint256 id)
        internal
        view
        returns (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        (,, token0, token1,, tickLower, tickUpper,,,,,) = INonfungiblePositionManager(asset).positions(id);

        // For deposited assets, the liquidity of the Liquidity Position is stored in the Pricing Module,
        // not fetched from the NonfungiblePositionManager.
        // Since liquidity of a position can be increased by a non-owner, the max exposure checks could otherwise be circumvented.
        liquidity = positions[asset][id].liquidity;

        if (liquidity == 0) {
            // Only used as an off-chain view function to return the value of a non deposited Liquidity Position.
            (,,,,,,, liquidity,,,,) = INonfungiblePositionManager(asset).positions(id);
        }
    }

    /**
     * @notice Calculates the underlying token amounts of a Liquidity Position, given external trusted prices.
     * @param tickLower The lower tick of the Liquidity Position.
     * @param tickUpper The upper tick of the Liquidity Position.
     * @param priceToken0 The price of 10^18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 10^18 tokens of token1 in USD, with 18 decimals precision.
     * @return amount0 The amount of underlying token0 tokens.
     * @return amount1 The amount of underlying token1 tokens.
     */
    function _getPrincipal(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 priceToken0,
        uint256 priceToken1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Calculate the square root of the relative rate sqrt(token1/token0) from the trusted USD-price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        // Calculate amount0 and amount1 of the principal (the Liquidity Position without accumulated fees).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 10^18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 10^18 tokens of token1 in USD, with 18 decimals precision.
     * @return sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @dev The price in Uniswap V3 is defined as:
     * price = amountToken1/amountToken0.
     * The usdPriceToken is defined as: usdPriceToken = amountUsd/amountToken.
     * => amountToken = amountUsd/usdPriceToken.
     * Hence we can derive the Uniswap V3 price as:
     * price = (amountUsd/usdPriceToken1)/(amountUsd/usdPriceToken0) = usdPriceToken0/usdPriceToken1.
     */
    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        // Both priceTokens have 18 decimals precision and result of division should also have 18 decimals precision.
        // -> multiply numerator by 10**18.
        uint256 priceXd18 = priceToken0.mulDivDown(1e18, priceToken1);
        // Square root of a number with 18 decimals precision has 9 decimals precision.
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        // Change sqrtPrice from a decimal fixed point number with 9 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd9 << FixedPoint96.RESOLUTION) / 1e9);
    }

    /**
     * @notice Calculates the underlying token amounts of both tokensOwed and accrued fees.
     * @param asset The contract address of the asset.
     * @param id The Id of the Liquidity Position.
     * @return tokensOwedAndFee0 The sum of tokensOwed0 and fee0 of underlying token0 tokens.
     * @return tokensOwedAndFee1 The sum of tokensOwed1 and fee1 of underlying token1 tokens.
     */
    function _getTokensOwedAndFees(address asset, uint256 id) internal view returns (uint256, uint256) {
        address factory = assetToV3Factory[asset];

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidity, // gas: cheaper to use uint256 instead of uint128.
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint256 tokensOwed0, // gas: cheaper to use uint256 instead of uint128.
            uint256 tokensOwed1 // gas: cheaper to use uint256 instead of uint128.
        ) = INonfungiblePositionManager(asset).positions(id);

        return _getTokensOwedAndFees(
            PoolAddress.computeAddress(factory, token0, token1, fee),
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
    }

    /**
     * @notice Calculates the underlying token amounts of both tokensOwed and accrued fees.
     * @param poolAddress The contract address of the UniV3 pool.
     * @param tickLower The lower tick of the Liquidity Position.
     * @param tickUpper The upper tick of the Liquidity Position.
     * @param liquidity The liquidity per tick of the Liquidity Position.
     * @param feeGrowthInside0LastX128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries.
     * @param feeGrowthInside1LastX128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries.
     * @param tokensOwed0 The amount of token0 owed to the position owner.
     * @param tokensOwed1 The amount of token1 owed to the position owner.
     * @return tokensOwedAndFee0 The sum of tokensOwed0 and fee0 of underlying token0 tokens.
     * @return tokensOwedAndFee1 The sum of tokensOwed1 and fee1 of underlying token1 tokens.
     */
    function _getTokensOwedAndFees(
        address poolAddress,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint256 tokensOwed0,
        uint256 tokensOwed1
    ) internal view returns (uint256 tokensOwedAndFee0, uint256 tokensOwedAndFee1) {
        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            _getFeeGrowthInside(poolAddress, tickLower, tickUpper);

        // Calculate the total amount of fees by adding the already realized fees (tokensOwed),
        // to the accumulated fees since the last time the position was updated:
        // (feeGrowthInsideCurrentX128 - feeGrowthInsideLastX128) * liquidity.
        // Fee calculations in NonfungiblePositionManager.sol overflow (without reverting) when
        // one or both terms, or their sum, is bigger than a uint128.
        // This is however much bigger than any realistic situation.
        unchecked {
            tokensOwedAndFee0 = FullMath.mulDiv(
                feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed0;
            tokensOwedAndFee1 = FullMath.mulDiv(
                feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed1;
        }
    }

    /**
     * @notice Calculates the current fee growth inside the Liquidity Range.
     * @param poolAddress The contract address of the pool.
     * @param tickLower The lower tick of the Liquidity Position.
     * @param tickUpper The upper tick of the Liquidity Position.
     * @return feeGrowthInside0X128 The current fee growth inside the Liquidity Position of token0 per unit of liquidity.
     * @return feeGrowthInside1X128 The current fee growth inside the Liquidity Position of token1 per unit of liquidity.
     */
    function _getFeeGrowthInside(address poolAddress, int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // To calculate the pending fees, the current tick has to be used, even if the pool would be unbalanced.
        (, int24 tickCurrent,,,,,) = pool.slot0();
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

        // Calculate the fee growth inside of the Liquidity Range since the last time the position was updated.
        // feeGrowthInside can overflow (without reverting), as is the case in the Uniswap fee calculations.
        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                feeGrowthInside0X128 =
                    pool.feeGrowthGlobal0X128() - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 =
                    pool.feeGrowthGlobal1X128() - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum exposure for an underlying asset.
     * @param asset The contract address of the underlying asset.
     * @param maxExposure The maximum protocol wide exposure to the underlying asset.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setExposureOfAsset(address asset, uint256 maxExposure) public override {
        // Authorization that only Risk Manager can set a new maxExposure is done in parent function.
        super.setExposureOfAsset(asset, maxExposure);

        // If the maximum exposure for an asset is set for the first time, check that the asset can be priced
        // by the erc20PricingModule.
        if (exposure[asset].exposure == 0) {
            require(PricingModule(erc20PricingModule).inPricingModule(asset), "PMUV3_SEOA: Unknown asset");
        }
    }

    /**
     * @notice Processes the deposit of an asset.
     * param vault The contract address of the Vault where the asset is transferred to.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * param amount The amount of tokens.
     * @dev The exposure caps are not defined per asset (LP token), but for the underlying assets over all Uniswap V3 LP-pools
     * (and optionally it's forks). Unfortunately it is not possible to use a single exposure across Pricing Modules,
     * so it does not take into account the exposure in for instance the erc20PricingModule.
     * @dev We enforce that the lower and upper boundary of the Liquidity Range must be within 5x of the current tick.
     * Without a limitation, malicious users could max out the the exposure caps (and deny service for other users) of the underlying assets,
     * by depositing little liquidity in ranges far outside of the current tick.
     * The chosen max range (from 0.2x to 5X the current price) is a trade-off between not hindering normal usage of LPs and
     * making it expensive for malicious actors to manipulate exposures (now they have to deposit at least 20% of the max exposure).
     */
    function processDeposit(address, address asset, uint256 assetId, uint256) external override onlyMainReg {
        // Call internal function with just two input variables to avoid stack to deep.
        _processDeposit(assetId, asset);
    }

    /**
     * @notice Processes the deposit of an asset.
     * @param assetId The Id of the asset.
     * @param asset The contract address of the asset.
     */
    function _processDeposit(uint256 assetId, address asset) internal {
        // Fetch position info, we name tokensOwed as exposureDelta to eliminate two local variables.
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint256 exposureDelta0,
            uint256 exposureDelta1
        ) = INonfungiblePositionManager(asset).positions(assetId);

        require(liquidity > 0, "PMUV3_PD: 0 liquidity");

        {
            int256 tickCurrent = _getTrustedTickCurrent(token0, token1);

            // The liquidity must be in an acceptable range (from 0.2x to 5x the current price).
            // Tick difference defined as: (sqrt(1.0001))log(sqrt(5)) = 16095.2
            require(tickCurrent - tickLower <= MAX_TICK_DIFFERENCE, "PMUV3_PD: Tlow not in limits");
            require(tickUpper - tickCurrent <= MAX_TICK_DIFFERENCE, "PMUV3_PD: Tup not in limits");
        }

        // Add pending fees to exposureDelta.
        (exposureDelta0, exposureDelta1) = _getTokensOwedAndFees(
            PoolAddress.computeAddress(assetToV3Factory[asset], token0, token1, fee),
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            exposureDelta0, // equals tokensOwed0.
            exposureDelta1 // equals tokensOwed1.
        );

        // Add the exposure of the principal to exposureDelta.
        {
            uint160 sqrtRatioLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            // Calculate the maximal possible exposure due to the principal and add it to exposureDelta.
            // Maximal exposure occurs when tickCurrent is outside the Liquidity range.
            exposureDelta0 += LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity);
            exposureDelta1 += LiquidityAmounts.getAmount1ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity);
        }

        {
            // Calculate updated total exposure.
            uint256 exposure0 = exposureDelta0 + exposure[token0].exposure;
            uint256 exposure1 = exposureDelta1 + exposure[token1].exposure;

            // Check that exposure doesn't exceed maxExposure
            require(exposure0 <= exposure[token0].maxExposure, "PMUV3_PD: Exposure0 not in limits");
            require(exposure1 <= exposure[token1].maxExposure, "PMUV3_PD: Exposure1 not in limits");

            // Update exposure
            // Unsafe casts: we already know from previous requires that exposure is smaller than maxExposure (uint128).
            exposure[token0].exposure = uint128(exposure0);
            exposure[token1].exposure = uint128(exposure1);
        }

        // Store information of the position.
        positions[asset][assetId] = Position({
            exposureDelta0: uint96(exposureDelta0),
            token0: token0,
            exposureDelta1: uint96(exposureDelta1),
            token1: token1,
            liquidity: liquidity
        });
    }

    /**
     * @notice Calculates the current tick from trusted USD prices of both tokens.
     * @param token0 The contract address of token0.
     * @param token1 The contract address of token1.
     * @return tickCurrent The current tick.
     */
    function _getTrustedTickCurrent(address token0, address token1) internal view returns (int256 tickCurrent) {
        // We use the USD price per 10^18 tokens instead of the USD price per token to guarantee
        // sufficient precision.
        (uint256 priceToken0,,,) = PricingModule(erc20PricingModule).getValue(
            GetValueInput({ asset: token0, assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
        );
        (uint256 priceToken1,,,) = PricingModule(erc20PricingModule).getValue(
            GetValueInput({ asset: token1, assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
        );

        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        tickCurrent = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /**
     * @notice Processes the withdrawal of an asset.
     * param vault The address of the vault where the asset is withdrawn from
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * param amount The amount of tokens.
     * @dev Unsafe cast to uint128, we know that the same cast did not overflow in deposit().
     */
    function processWithdrawal(address, address asset, uint256 assetId, uint256) external override onlyMainReg {
        // Update exposure to underlying assets.
        exposure[positions[asset][assetId].token0].exposure -= positions[asset][assetId].exposureDelta0;
        exposure[positions[asset][assetId].token1].exposure -= positions[asset][assetId].exposureDelta1;
    }
}
