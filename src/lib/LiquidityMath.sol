// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
            uint256 newReserveRA, // Updated reserve of RA
            uint256 newReserveCT, // Updated reserve of CT
            uint256 liquidityMinted // Amount of liquidity tokens minted
        )
    {
        // Ensure the added amounts are proportional
        require(amount0 * reserve1 == amount1 * reserve0, "Non-proportional liquidity");

        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        if (totalLiquidity == 0) {
            // Initial liquidity provision (sqrt of product of amounts added)
            liquidityMinted = sqrt(amount0 * amount1);
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = (amount0 * totalLiquidity) / reserve0;
        }

        // Update reserves
        newReserveRA = reserve0 + amount0;
        newReserveCT = reserve1 + amount1;

        return (newReserveRA, newReserveCT, liquidityMinted);
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
            uint256 newReserveRA, // Updated reserve of RA
            uint256 newReserveCT // Updated reserve of CT
        )
    {
        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(totalLiquidity > 0, "No liquidity available");

        // Calculate the proportion of reserves to return based on the liquidity removed
        amount0 = (liquidityAmount * reserve0) / totalLiquidity;
        amount1 = (liquidityAmount * reserve1) / totalLiquidity;

        // Update reserves after removing liquidity
        newReserveRA = reserve0 - amount0;
        newReserveCT = reserve1 - amount1;

        return (amount0, amount1, newReserveRA, newReserveCT);
    }

    // Helper function to calculate square root
    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
