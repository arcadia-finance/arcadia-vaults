// https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param token0 Contract address of token0.
    /// @param token1 Contract address of token1.
    /// @param fee The fee of the pool.
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, address token0, address token1, uint24 fee)
        internal
        pure
        returns (address pool)
    {
        require(token0 < token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", factory, keccak256(abi.encode(token0, token1, fee)), POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
