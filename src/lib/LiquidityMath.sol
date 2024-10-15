// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LiquidityMath {

    // Adding Liquidity (Pure Function)
    function addLiquidity(
        uint256 reserveRA, // Current reserve of RA (target token)
        uint256 reserveCT, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 amountRA, // Amount of RA to add
        uint256 amountCT // Amount of CT to add
    ) internal pure returns (
        uint256 newReserveRA, // Updated reserve of RA
        uint256 newReserveCT, // Updated reserve of CT
        uint256 liquidityMinted // Amount of liquidity tokens minted
    ) {
        // Ensure the added amounts are proportional
        require(amountRA * reserveCT == amountCT * reserveRA, "Non-proportional liquidity");

        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        if (totalLiquidity == 0) {
            // Initial liquidity provision (sqrt of product of amounts added)
            liquidityMinted = sqrt(amountRA * amountCT);
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = (amountRA * totalLiquidity) / reserveRA;
        }

        // Update reserves
        newReserveRA = reserveRA + amountRA;
        newReserveCT = reserveCT + amountCT;

        return (newReserveRA, newReserveCT, liquidityMinted);
    }

    // Removing Liquidity (Pure Function)
    function removeLiquidity(
        uint256 reserveRA, // Current reserve of RA (target token)
        uint256 reserveCT, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 liquidityAmount // Amount of liquidity tokens being removed
    ) internal pure returns (
        uint256 amountRA, // Amount of RA returned to the LP
        uint256 amountCT, // Amount of CT returned to the LP
        uint256 newReserveRA, // Updated reserve of RA
        uint256 newReserveCT // Updated reserve of CT
    ) {
        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(totalLiquidity > 0, "No liquidity available");

        // Calculate the proportion of reserves to return based on the liquidity removed
        amountRA = (liquidityAmount * reserveRA) / totalLiquidity;
        amountCT = (liquidityAmount * reserveCT) / totalLiquidity;

        // Update reserves after removing liquidity
        newReserveRA = reserveRA - amountRA;
        newReserveCT = reserveCT - amountCT;

        return (amountRA, amountCT, newReserveRA, newReserveCT);
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
