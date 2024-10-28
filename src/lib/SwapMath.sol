pragma solidity ^0.8.0;

import "./balancers/FixedPoint.sol";
import "./balancers/LogExpMath.sol";

library SwapMath {
    using FixedPoint for uint256;

    /// @notice amountOut =  reserveOut - (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 kInitial,
        uint256 _1MinT,
        uint256 baseFee
    ) internal pure returns (uint256 amountOut) {
        // Calculate fee factor = 1 - feePercentage
        uint256 feeFactor = FixedPoint.complement(baseFee.mulDown(_1MinT));
        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = amountIn.mulDown(feeFactor);

        uint256 reserveInExp = FixedPoint.powDown(reserveIn, _1MinT);
        uint256 reserveOutExp = FixedPoint.powDown(reserveOut, _1MinT);
        uint256 k = reserveInExp.add(reserveOutExp);

        assert(k >= kInitial);
        // Calculate q = (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
        uint256 q = FixedPoint.powDown(reserveIn.add(amountIn), _1MinT);
        q = FixedPoint.powDown(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountOut = reserveOut - q
        amountOut = reserveOut.sub(q);
    }

    /// @notice amountIn = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 kInitial,
        uint256 _1MinT,
        uint256 baseFee
    ) internal pure returns (uint256 amountIn) {
        uint256 reserveInExp = FixedPoint.powDown(reserveIn, _1MinT);
        uint256 reserveOutExp = FixedPoint.powDown(reserveOut, _1MinT);
        uint256 k = reserveInExp.add(reserveOutExp);

        assert(k >= kInitial);
        // Calculate q = (reserveOut - amountOut)^(1-t))^1/(1-t)
        uint256 q = FixedPoint.powDown(reserveOut.sub(amountOut), _1MinT);
        q = FixedPoint.powDown(k.sub(q), FixedPoint.ONE.divDown(_1MinT));

        // Calculate amountIn = q - reserveIn
        amountIn = q.sub(reserveIn);
        // Calculate fee factor = 1 - feePercentage
        uint256 feeFactor = FixedPoint.complement(baseFee.mulDown(_1MinT));
        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = amountIn.mulDown(feeFactor);
    }

    /// @notice Get normalized time (t) as a value between 0 and 1
    function getNormalizedTime(uint256 startTime, uint256 maturityTime) public view returns (uint256 t) {
        uint256 elapsedTime = block.timestamp.sub(startTime);
        uint256 totalDuration = maturityTime.sub(startTime);

        require(elapsedTime <= totalDuration, "Past maturity");

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        t = elapsedTime.divDown(totalDuration);
    }

    /// @notice calculate 1 - t
    function oneMinusT(uint256 startTime, uint256 maturityTime) public view returns (uint256) {
        return FixedPoint.complement(getNormalizedTime(startTime, maturityTime));
    }

    /// @notice feePercentage =  baseFee x t. where t is normalized time
    function getFeePercentage(uint256 baseFee, uint256 startTime, uint256 maturityTime) public view returns (uint256) {
        uint256 t = getNormalizedTime(startTime, maturityTime);
        return baseFee.mulDown(t);
    }

    /// @notice calculate percentage of an amount = amount * percentage / 100
    function calculatePercentage(uint256 percentage, uint256 amount) public pure returns (uint256) {
        return amount.mulDown(percentage).divDown(FixedPoint.ONE * 100);
    }

    /// @notice calculate fee = amount * (baseFee x t) / 100
    function getFee(uint256 amount, uint256 baseFee, uint256 startTime, uint256 maturityTime)
        public
        view
        returns (uint256)
    {
        uint256 feePercentage = getFeePercentage(baseFee, startTime, maturityTime);
        return calculatePercentage(feePercentage, amount);
    }

    /// @notice calculate k = x^(1-t) + y^(1-t)
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
        k = xTerm.add(yTerm);
    }
}
