pragma solidity ^0.8.0;

import "./balancers/FixedPoint.sol";
import "./balancers/LogExpMath.sol";
import "forge-std/console.sol";

library SwapMath {
    using FixedPoint for uint256;

    /// @notice amountOut = reserveOut - (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 kInitial,
        uint256 _1MinT,
        uint256 baseFee
    ) internal pure returns (uint256 amountOut) {
       // Calculate fee factor = baseFee x t in percentage, we complement _1MinT to get t
        // the end result should be total fee that we must take out
        uint256 feeFactor = baseFee.mulDown(_1MinT.complement());
        uint256 fee = calculatePercentage(amountIn, feeFactor);

        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = amountIn.sub(fee);

        uint256 reserveInExp = LogExpMath.pow(reserveIn, _1MinT);
        console.log("reserveInExp: ", reserveInExp);

        uint256 reserveOutExp = LogExpMath.pow(reserveOut, _1MinT);
        console.log("reserveOutExp: ", reserveOutExp);

        uint256 k = reserveInExp.add(reserveOutExp);

        assert(k >= kInitial);
        // Calculate q = (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
        uint256 q = reserveIn.add(amountIn);
        q = LogExpMath.pow(q, _1MinT);
        q = LogExpMath.pow(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountOut = reserveOut - q
        amountOut = reserveOut.sub(q);
    }

    /// @notice amountIn = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
    /// fee = amountIn * baseFee x t
    /// receive = amountIn - fee
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 kInitial,
        uint256 _1MinT,
        uint256 baseFee
    ) internal pure returns (uint256 amountIn) {
        uint256 reserveInExp = LogExpMath.pow(reserveIn, _1MinT);
        console.log("reserveInExp: ", reserveInExp);

        uint256 reserveOutExp = LogExpMath.pow(reserveOut, _1MinT);
        console.log("reserveOutExp: ", reserveOutExp);
        
        uint256 k = reserveInExp.add(reserveOutExp);

        assert(k >= kInitial);
        // Calculate q = (reserveOut - amountOut)^(1-t))^1/(1-t)
        uint256 q = LogExpMath.pow(reserveOut.sub(amountOut), _1MinT);
        q = LogExpMath.pow(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountIn = q - reserveIn
        amountIn = q.sub(reserveIn);

        // Calculate fee factor = baseFee x t in percentage, we complement _1MinT to get t
        // the end result should be total fee that we must take out
        uint256 feeFactor = baseFee.mulDown(_1MinT.complement());
        uint256 fee = calculatePercentage(amountIn, feeFactor);

        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = amountIn.sub(fee);
    }

    /// @notice Get normalized time (t) as a value between 0 and 1
    function getNormalizedTimeToMaturity(uint256 startTime, uint256 maturityTime, uint256 currentTime)
        public
        pure
        returns (uint256 t)
    {
        uint256 elapsedTime = currentTime.sub(startTime);
        uint256 totalDuration = maturityTime.sub(startTime);

        require(elapsedTime <= totalDuration, "Past maturity");

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
