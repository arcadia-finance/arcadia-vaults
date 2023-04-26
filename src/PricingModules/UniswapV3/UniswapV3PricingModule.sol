/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { PricingModule, IPricingModule } from "../AbstractPricingModule.sol";
import { IMainRegistry } from "../interfaces/IMainRegistry.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
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
contract UniswapV3PricingModule is PricingModule {
    using FixedPointMathLib for uint256;
    using FullMath for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => uniswapV3Factory.
    mapping(address => address) public assetToV3Factory;

    // The Arcadia Pricing Module for standard ERC20 tokens (the underlying assets).
    PricingModule immutable erc20PricingModule;

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param oracleHub_ The contract address of the OracleHub.
     * @param riskManager_ The address of the Risk Manager.
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
     * and each liquidity position will have a different id.
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
                        ALLOW LIST MANAGEMENT
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
     * @notice Returns the value of a Uniswap 3 Liquidity Range, denominated in USD.
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
            (,, token0, token1,, tickLower, tickUpper, liquidity,,,,) = INonfungiblePositionManager(asset).positions(id);

            // Uniswap Pools can be manipulated, we can't rely on the current price (or tick).
            // We use Chainlink oracles of the underlying assets to calculate the flashloan resistant current price.
            // usdPriceToken is the USD price for 10**18 (or 1 WAD) of tokens, it has a precision of: 36-tokenDecimals.
            (usdPriceToken0,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token0, assetId: 0, assetAmount: FixedPointMathLib.WAD, baseCurrency: 0 })
            );
            (usdPriceToken1,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token1, assetId: 0, assetAmount: FixedPointMathLib.WAD, baseCurrency: 0 })
            );

            // Calculate amount0 and amount1 of the principal (the actual liquidity position).
            (principal0, principal1) =
                _getPrincipalAmounts(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
        }

        {
            // Calculate amount0 and amount1 of the accumulated fees.
            (uint256 fee0, uint256 fee1) = _getFeeAmounts(asset, id);

            // Calculate the total value in USD, with 18 decimals precision.
            // usdPriceToken has precision: 36-tokenDecimals.
            // (principal0 + fee0) has precision: tokenDecimals.
            valueInUsd = usdPriceToken0.mulDivDown(principal0 + fee0, FixedPointMathLib.WAD)
                + usdPriceToken1.mulDivDown(principal1 + fee1, FixedPointMathLib.WAD);
        }

        {
            // Fetch the risk variables of the underlying tokens for the given baseCurrency.
            (uint256 collateralFactor0, uint256 liquidationFactor0) =
                PricingModule(erc20PricingModule).getRiskVariables(token0, baseCurrency);
            (uint256 collateralFactor1, uint256 liquidationFactor1) =
                PricingModule(erc20PricingModule).getRiskVariables(token1, baseCurrency);

            // We take the most conservative factor of both underlying assets.
            // If one token loses in value compared to the other token, Liquidity Providers will be relatively more exposed
            // to the asset that loses value. This is especially true for Uniswap V3: when the current tick is outside of the
            // liquidity range the LP is fully exposed to a single asset.
            collateralFactor = collateralFactor0 > collateralFactor1 ? collateralFactor1 : collateralFactor0;
            liquidationFactor = liquidationFactor0 > liquidationFactor1 ? liquidationFactor1 : liquidationFactor0;
        }

        return (valueInUsd, 0, collateralFactor, liquidationFactor);
    }

    function _getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 usdPriceToken0,
        uint256 usdPriceToken1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Calculate the square root of the relative rate sqrt(token1/token0) from the USD-price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(usdPriceToken0, usdPriceToken1);

        // Calculate amount0 and amount1 of the principal (the actual liquidity position).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        uint256 priceXd18 = priceToken1.mulDivDown(FixedPointMathLib.WAD, priceToken0);
        uint256 sqrtPriceXd18 = FixedPointMathLib.sqrt(priceXd18);

        // Change sqrtPrice from a decimal fixed point number with 18 digits to a binary fixed point number with 96 digits.
        sqrtPriceX96 = uint160(sqrtPriceXd18 << FixedPoint96.RESOLUTION / FixedPointMathLib.WAD);
    }

    function _getFeeAmounts(address asset, uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
        address factory = assetToV3Factory[asset]; // Have to cache the factory address to avoid a stack too deep error.
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
            uint256 tokensOwed0,
            uint256 tokensOwed1
        ) = INonfungiblePositionManager(asset).positions(id);

        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            _getFeeGrowthInside(factory, token0, token1, fee, tickLower, tickUpper);

        // Calculate the total amount of fees by adding the already realized fees (tokensOwed), to the accumulated fees
        // since the last time the position was updated ((feeGrowthInsideCurrentX128 - feeGrowthInsideLastX128) * liquidity).
        amount0 = FullMath.mulDiv(feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128)
            + tokensOwed0;
        amount1 = FullMath.mulDiv(feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128)
            + tokensOwed1;
    }

    function _getFeeGrowthInside(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, token0, token1, fee));

        // To calculate the pending fees, the actual current tick has to be used, even if the pool would be manipulated.
        (, int24 tickCurrent,,,,,) = pool.slot0();
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

        // Calculate the fee growth inside of the Liquidity Range since the last time the position was updated.
        if (tickCurrent < tickLower) {
            feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else if (tickCurrent < tickUpper) {
            feeGrowthInside0X128 = pool.feeGrowthGlobal0X128() - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = pool.feeGrowthGlobal1X128() - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else {
            feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
            feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

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
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
            INonfungiblePositionManager(asset).positions(assetId);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(assetToV3Factory[asset], token0, token1, fee));

        // We calculate current tick via the TWAP price. TWAP prices can be manipulated, but it is costly (not atomic).
        // We do not use the TWAP price to calculate the current value of the asset, only to ensure ensure that the deposited Liquidity Range
        // hence the risk of manipulation is acceptable since it can never be used to steal funds (only to deposit ranges further than 5x).
        int24 tickCurrent = _getTickTwap(pool);

        // The liquidity must be in an acceptable range (from 0.2x to 5X the current price).
        // Tick difference defined as: (sqrt(1.0001))log(sqrt(5)) = 16095.2
        require(tickCurrent - tickLower <= 16_095, "PMUV3_PD: Range not in limits");
        require(tickUpper - tickCurrent <= 16_095, "PMUV3_PD: Range not in limits");

        // Cache sqrtRatio.
        uint160 sqrtRatioLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Calculate the maximal possible exposure to each underlying asset.
        uint128 amount0Max = SafeCastLib.safeCastTo128(
            LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity)
        );
        uint128 amount1Max = SafeCastLib.safeCastTo128(
            LiquidityAmounts.getAmount1ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity)
        );

        // Update exposure to underlying assets.
        require(
            exposure[token0].exposure + amount0Max <= exposure[token0].maxExposure, "PMUV3_PD: Exposure not in limits"
        );
        require(
            exposure[token1].exposure + amount1Max <= exposure[token1].maxExposure, "PMUV3_PD: Exposure not in limits"
        );
        exposure[token0].exposure += amount0Max;
        exposure[token1].exposure += amount1Max;
    }

    function _getTickTwap(IUniswapV3Pool pool) internal view returns (int24 tick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[1] = 300; // We take a 5 minute time interval.

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

        tick = int24((tickCumulatives[0] - tickCumulatives[1]) / 300);
    }

    /**
     * @notice Processes the withdrawal an asset.
     * param vault The address of the vault where the asset is withdrawn from
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * param amount The amount of tokens.
     * @dev Unsafe cast to uint128, we know that the same cast did not overflow in deposit().
     */
    function processWithdrawal(address, address asset, uint256 assetId, uint256) external override onlyMainReg {
        (,, address token0, address token1,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
            INonfungiblePositionManager(asset).positions(assetId);

        // Cache sqrtRatio.
        uint160 sqrtRatioLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Calculate the maximal possible exposure to each underlying asset.
        uint128 amount0Max =
            uint128(LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity));
        uint128 amount1Max =
            uint128(LiquidityAmounts.getAmount1ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity));

        // Update exposure to underlying assets.
        exposure[token0].exposure -= amount0Max;
        exposure[token1].exposure -= amount1Max;
    }
}
