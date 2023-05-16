/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { INonfungiblePositionManager } from "../PricingModules/UniswapV3/interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "../PricingModules/UniswapV3/interfaces/IUniswapV3Pool.sol";

import { TickMath } from "../PricingModules/UniswapV3/libraries/TickMath.sol";
import { PoolAddress } from "../PricingModules/UniswapV3/libraries/PoolAddress.sol";
import { LiquidityAmounts } from "../PricingModules/UniswapV3/libraries/LiquidityAmounts.sol";

interface IUniswapV3PricingModule {
    function assetToV3Factory(address) external view returns (address);

    struct Exposure {
        uint128 maxExposure; // The maximum protocol wide exposure to an asset.
        uint128 exposure; // The actual protocol wide exposure to an asset.
    }

    function exposure(address) external view returns (Exposure memory);
}

contract UniV3Helper {
    IUniswapV3PricingModule public immutable uniswapV3PricingModule;

    struct NftInfo {
        address asset;
        uint256 assetId;
        address token0;
        address token1;
        uint24 fee;
        bool allowed;
        string message;
    }

    constructor(address _uniswapV3PricingModule) {
        uniswapV3PricingModule = IUniswapV3PricingModule(_uniswapV3PricingModule);
    }

    /**
     * @param nftAssets The addresses of the NFT assets.
     * @param assetIds The ids of the NFTs.
     * @return nftInfo The info of the NFTs.
     */
    function getDepositInfo(address[] calldata nftAssets, uint256[] calldata assetIds)
        public
        view
        returns (NftInfo[] memory nftInfo)
    {
        for (uint256 i; i < nftAssets.length;) {
            for (uint256 j; j < assetIds.length;) {
                nftInfo[j] = getNftInfo(nftAssets[i], assetIds[j]);

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @param asset The address of the NFT asset.
     * @param assetId The id of the NFT.
     * @return nftInfo The info of the NFT.
     */
    function getNftInfo(address asset, uint256 assetId) public view returns (NftInfo memory nftInfo) {
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
            INonfungiblePositionManager(asset).positions(assetId);

        {
            IUniswapV3Pool pool = IUniswapV3Pool(
                PoolAddress.computeAddress(uniswapV3PricingModule.assetToV3Factory(asset), token0, token1, fee)
            );

            // We calculate current tick via the TWAP price. TWAP prices can be manipulated, but it is costly (not atomic).
            // We do not use the TWAP price to calculate the current value of the asset, only to ensure that the deposited Liquidity Range
            // hence the risk of manipulation is acceptable since it can never be used to steal funds (only to deposit ranges further than 5x).
            int24 tickCurrent = _getTwat(pool);

            // The liquidity must be in an acceptable range (from 0.2x to 5X the current price).
            // Tick difference defined as: (sqrt(1.0001))log(sqrt(5)) = 16095.2
            if (tickCurrent - tickLower <= 16_095) {
                return NftInfo(asset, assetId, address(0), address(0), 0, false, "PMUV3_CD: Tlow not in limits");
            }

            if (tickUpper - tickCurrent <= 16_095) {
                return NftInfo(asset, assetId, address(0), address(0), 0, false, "PMUV3_CD: Tup not in limits");
            }
        }

        // Cache sqrtRatio.
        uint160 sqrtRatioLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Calculate the maximal possible exposure to each underlying asset.
        uint256 amount0Max = LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity);
        uint256 amount1Max = LiquidityAmounts.getAmount1ForLiquidity(sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity);

        // Calculate updated exposure.
        uint256 exposure0 = amount0Max + uniswapV3PricingModule.exposure(token0).exposure;
        uint256 exposure1 = amount1Max + uniswapV3PricingModule.exposure(token1).exposure;

        // Check that exposure doesn't exceed maxExposure
        if (exposure0 <= uniswapV3PricingModule.exposure(token0).maxExposure) {
            return NftInfo(asset, assetId, address(0), address(0), 0, false, "PMUV3_CD: Exposure0 not in limits");
        }
        if (exposure1 <= uniswapV3PricingModule.exposure(token1).maxExposure) {
            return NftInfo(asset, assetId, address(0), address(0), 0, false, "PMUV3_CD: Exposure1 not in limits");
        }

        return NftInfo(asset, assetId, token0, token1, fee, true, "");
    }

    /**
     * @notice Calculates the time weighted average tick over 300s.
     * @param pool The liquidity pool.
     * @return tick The time weighted average tick over 300s.
     * @dev We do not use the TWAT price to calculate the current value of the asset.
     * It is used only to ensure that the deposited Liquidity range and thus
     * the risk of exposure manipulation is acceptable.
     */
    function _getTwat(IUniswapV3Pool pool) internal view returns (int24 tick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[1] = 300; // We take a 5 minute time interval.

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

        tick = int24((tickCumulatives[0] - tickCumulatives[1]) / 300);
    }
}
