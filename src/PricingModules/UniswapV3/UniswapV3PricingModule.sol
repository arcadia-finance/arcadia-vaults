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

/**
 * @title Pricing Module for Uniswap V3 Liquidity Positions.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Uniswap V3 Liquidity Positions.
 * @dev The UniV3PriceModule will not price the LP-tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 * @dev No end-user should directly interact with the UniV3PriceModule, only the Main-registry,
 * or the contract owner.
 */
contract UniV3PriceModule is PricingModule {
    using FixedPointMathLib for uint256;
    using FullMath for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    PricingModule immutable erc20PricingModule;

    address public uniswapV3Factory;

    struct Position {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

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
        uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        erc20PricingModule = PricingModule(erc20PricingModule_);
    }

    /*///////////////////////////////////////////////////////////////
                        ALLOW LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the UniV3PriceModule.
     * @param asset The contract address of the asset (also known as the NonfungiblePositionManager).
     * @dev Per protocol (eg. Uniswap V3 and its forks) there is a single asset,
     * and each liquidity position will have a different id.
     */
    function addAsset(address asset) external onlyOwner {
        require(!inPricingModule[asset], "PM20_AA: already added");

        // Will revert in MainRegistry if asset can't be added.
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    function getValue(IPricingModule.GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256, uint256 collateralFactor, uint256 liquidationFactor)
    {
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
            // We use Chainlink oracles of the underlying assets to calculate the flashloan resistant price.
            (usdPriceToken0,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token0, assetId: 0, assetAmount: FixedPointMathLib.WAD, baseCurrency: 0 })
            );
            (usdPriceToken1,,,) = PricingModule(erc20PricingModule).getValue(
                GetValueInput({ asset: token1, assetId: 0, assetAmount: FixedPointMathLib.WAD, baseCurrency: 0 })
            );

            // Calculate amount0 and amount1 of the principal (liquidity position)
            (principal0, principal1) =
                getPrincipalAmounts(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
        }

        {
            // Calculate amount0 and amount1 of the fees
            (uint256 fee0, uint256 fee1) = getFeeAmounts(asset, id);

            // Calculate total value in USD
            valueInUsd = usdPriceToken0.mulDivDown(principal0 + fee0, FixedPointMathLib.WAD)
                + usdPriceToken1.mulDivDown(principal1 + fee1, FixedPointMathLib.WAD);
        }

        {
            (uint256 collateralFactor0, uint256 liquidationFactor0) =
                PricingModule(erc20PricingModule).getRiskVariables(token0, baseCurrency);
            (uint256 collateralFactor1, uint256 liquidationFactor1) =
                PricingModule(erc20PricingModule).getRiskVariables(token1, baseCurrency);

            collateralFactor = collateralFactor0 > collateralFactor1 ? collateralFactor0 : collateralFactor1;
            liquidationFactor = liquidationFactor0 > liquidationFactor1 ? liquidationFactor0 : liquidationFactor1;
        }

        return (valueInUsd, 0, collateralFactor, liquidationFactor);
    }

    function getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 usdPriceToken0,
        uint256 usdPriceToken1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Uniswap Pools can be manipulated, we can't rely on the current price (or tick).
        // We use Chainlink oracles of the underlying assets to calculate the flashloan resistant price.
        uint160 sqrtPriceX96 = getSqrtPriceX96(usdPriceToken0, usdPriceToken1);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        uint256 priceXd18 = priceToken1.mulDivDown(FixedPointMathLib.WAD, priceToken0);
        uint256 sqrtPriceXd18 = FixedPointMathLib.sqrt(priceXd18);

        // Change sqrtPrice from a decimal fixed point number with 18 digits to a binary fixed point number with 96 digits.
        sqrtPriceX96 = uint160(sqrtPriceXd18 << FixedPoint96.RESOLUTION / FixedPointMathLib.WAD);
    }

    function getFeeAmounts(address asset, uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
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

        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddress.computeAddress(
                uniswapV3Factory, PoolAddress.PoolKey({ token0: token0, token1: token1, fee: fee })
            )
        );

        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            getFeeGrowthInside(pool, tickLower, tickUpper);

        amount0 = FullMath.mulDiv(feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128)
            + tokensOwed0;

        amount1 = FullMath.mulDiv(feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128)
            + tokensOwed1;
    }

    function getFeeGrowthInside(IUniswapV3Pool pool, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (, int24 tickCurrent,,,,,) = pool.slot0();
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

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
}
