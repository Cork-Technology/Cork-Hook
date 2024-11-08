pragma solidity ^0.8.0;

import "./balancers/FixedPoint.sol";
import "forge-std/console.sol";

library SwapMath {
    using FixedPoint for uint256;

    /// @notice minimum 1-t to not div by 0
    uint256 public constant MINIMUM_ELAPSED = 1;

    /// @notice amountOut = reserveOut - (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 _1MinT, uint256 baseFee)
        public
        pure
        returns (uint256 amountOut)
    {
        // Calculate fee factor = baseFee x t in percentage, we complement _1MinT to get t
        // the end result should be total fee that we must take out
        uint256 feeFactor = baseFee.mulDown(_1MinT.complement());
        uint256 fee = calculatePercentage(amountIn, feeFactor);

        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = amountIn.sub(fee);

        uint256 reserveInExp = LogExpMath.pow(reserveIn, _1MinT);

        uint256 reserveOutExp = LogExpMath.pow(reserveOut, _1MinT);

        uint256 k = reserveInExp.add(reserveOutExp);

        // Calculate q = (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
        uint256 q = reserveIn.add(amountIn);
        q = LogExpMath.pow(q, _1MinT);
        q = LogExpMath.pow(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountOut = reserveOut - q
        amountOut = reserveOut.sub(q);
    }

    /// @notice amountIn = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 _1MinT, uint256 baseFee)
        public
        pure
        returns (uint256 amountIn)
    {
        uint256 reserveInExp = LogExpMath.pow(reserveIn, _1MinT);

        uint256 reserveOutExp = LogExpMath.pow(reserveOut, _1MinT);

        uint256 k = reserveInExp.add(reserveOutExp);

        // Calculate q = (reserveOut - amountOut)^(1-t))^1/(1-t)
        uint256 q = LogExpMath.pow(reserveOut.sub(amountOut), _1MinT);
        q = LogExpMath.pow(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountIn = q - reserveIn
        amountIn = q.sub(reserveIn);

        // normalize fee factor to 0-1
        uint256 feeFactor = baseFee.mulDown(_1MinT.complement()).divDown(100e18);
        feeFactor = FixedPoint.ONE.sub(feeFactor);

        amountIn = amountIn.divDown(feeFactor);
    }

    /// @notice Get normalized time (t) as a value between 1 and 0, it'll approach 0 as time goes on
    function getNormalizedTimeToMaturity(uint256 startTime, uint256 maturityTime, uint256 currentTime)
        public
        pure
        returns (uint256 t)
    {
        uint256 elapsedTime = currentTime.sub(startTime);
        elapsedTime = elapsedTime == 0 ? MINIMUM_ELAPSED : elapsedTime;
        uint256 totalDuration = maturityTime.sub(startTime);

        // we return 0 in case it's past maturity time
        if (elapsedTime >= totalDuration) {
            return 0;
        }

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        t = elapsedTime.divDown(totalDuration).complement();
    }

    /// @notice calculate 1 - t
    function oneMinusT(uint256 startTime, uint256 maturityTime, uint256 currentTime) public pure returns (uint256) {
        return FixedPoint.complement(getNormalizedTimeToMaturity(startTime, maturityTime, currentTime));
    }

    /// @notice feePercentage =  baseFee x t. where t is normalized time
    function getFeePercentage(uint256 baseFee, uint256 startTime, uint256 maturityTime, uint256 currentTime)
        public
        pure
        returns (uint256)
    {
        uint256 t = getNormalizedTimeToMaturity(startTime, maturityTime, currentTime);
        return baseFee.mulDown(t);
    }

    /// @notice calculate percentage of an amount = amount * percentage / 100
    function calculatePercentage(uint256 percentage, uint256 amount) public pure returns (uint256) {
        return amount.mulDown(percentage).divDown(FixedPoint.ONE * 100);
    }

    /// @notice calculate fee = amount * (baseFee x t) / 100
    function getFee(uint256 amount, uint256 baseFee, uint256 startTime, uint256 maturityTime, uint256 currentTime)
        public
        pure
        returns (uint256)
    {
        uint256 feePercentage = getFeePercentage(baseFee, startTime, maturityTime, currentTime);
        return calculatePercentage(feePercentage, amount);
    }

    /// @notice calculate k = x^(1-t) + y^(1-t)
    function getInvariant(
        uint256 reserve0,
        uint256 reserve1,
        uint256 startTime,
        uint256 maturityTime,
        uint256 currentTime
    ) public pure returns (uint256 k) {
        uint256 t = oneMinusT(startTime, maturityTime, currentTime);

        // Calculate x^(1-t) and y^(1-t) (x and y are reserveRA and reserveCT)
        uint256 xTerm = LogExpMath.pow(reserve0, t);
        uint256 yTerm = LogExpMath.pow(reserve1, t);

        // Invariant k is x^(1-t) + y^(1-t)
        k = xTerm.add(yTerm);
    }
}
