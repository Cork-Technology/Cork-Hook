// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./../interfaces/IErrors.sol";

library LiquidityMath {
    // Adding Liquidity (Pure Function)
    function addLiquidity(
        uint256 reserve0, // Current reserve of RA (target token)
        uint256 reserve1, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 amount0, // Amount of RA to add
        uint256 amount1 // Amount of CT to add
    )
        internal
        pure
        returns (
            uint256 newReserve0, // Updated reserve of RA
            uint256 newReserve1, // Updated reserve of CT
            uint256 liquidityMinted // Amount of liquidity tokens minted
        )
    {
        // Ensure the added amounts are proportional
        if (amount0 * reserve1 != amount1 * reserve0) {
            revert IErrors.InvalidAmount();
        }

        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        if (totalLiquidity == 0) {
            // Initial liquidity provision (sqrt of product of amounts added)
            liquidityMinted = Math.sqrt(amount0 * amount1);
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = (amount0 * totalLiquidity) / reserve0;
        }

        // Update reserves
        newReserve0 = reserve0 + amount0;
        newReserve1 = reserve1 + amount1;

        return (newReserve0, newReserve1, liquidityMinted);
    }

    // Removing Liquidity (Pure Function)
    function removeLiquidity(
        uint256 reserve0, // Current reserve of RA (target token)
        uint256 reserve1, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 liquidityAmount // Amount of liquidity tokens being removed
    )
        internal
        pure
        returns (
            uint256 amount0, // Amount of RA returned to the LP
            uint256 amount1, // Amount of CT returned to the LP
            uint256 newReserve0, // Updated reserve of RA
            uint256 newReserve1 // Updated reserve of CT
        )
    {
        if (liquidityAmount <= 0) {
            revert IErrors.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IErrors.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amount0 = (liquidityAmount * reserve0) / totalLiquidity;
        amount1 = (liquidityAmount * reserve1) / totalLiquidity;

        // Update reserves after removing liquidity
        newReserve0 = reserve0 - amount0;
        newReserve1 = reserve1 - amount1;

        return (amount0, amount1, newReserve0, newReserve1);
    }
}
