pragma solidity ^0.8.0;

import "./balancers/FixedPoint.sol";

library SwapMath {
    using FixedPoint for uint256;

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 k, uint256 _1MinT)
        internal
        pure
        returns (uint256 amountOut)
    {}

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 k, uint256 _1MinT)
        internal
        pure
        returns (uint256 amountIn)
    {}

    // Get normalized time (t) as a value between 0 and 1
    function getNormalizedTime(uint256 startTime, uint256 maturityTime) public view returns (uint256 t) {
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 totalDuration = maturityTime - startTime;

        require(elapsedTime <= totalDuration, "Past maturity");

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        t = elapsedTime * 1e18 / totalDuration;
    }

    // Return 1 - t
    function oneMinusT(uint256 startTime, uint256 maturityTime) public view returns (uint256) {
        return FixedPoint.complement(getNormalizedTime(startTime, maturityTime));
    }

    // Helper function to calculate k = x^(1-t) + y^(1-t)
    function getInvariant(uint256 reserve0, uint256 reserve1, uint256 startTime, uint256 maturityTime)
        public
        view
        returns (uint256 k)
    {
        uint256 t = oneMinusT(startTime, maturityTime);

        // Calculate x^(1-t) and y^(1-t) (x and y are reserveRA and reserveCT)
        uint256 xTerm = FixedPoint.powDown(reserve0, t);
        uint256 yTerm = FixedPoint.powDown(reserve1, t);

        // Invariant k is x^(1-t) + y^(1-t)
        k = xTerm + yTerm;
    }
}
