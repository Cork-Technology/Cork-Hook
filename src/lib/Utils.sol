pragma solidity 0.8.26;

library HookUtils {
    // Get normalized time (t) as a value between 0 and 1
    function getNormalizedTime(uint256 startTime, uint256 maturityTime) public view returns (uint256 t) {
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 totalDuration = maturityTime - startTime;

        require(elapsedTime <= totalDuration, "Past maturity");

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        t = elapsedTime * 1e18 / totalDuration;
    }

    // Helper function to calculate k = x^(1-t) + y^(1-t)
    function getInvariant(uint256 raReserve, uint256 ctReserve, uint256 startTime, uint256 maturityTime)
        public
        view
        returns (uint256 k)
    {
        uint256 t = getNormalizedTime(startTime, maturityTime);

        // Calculate (1 - t) as a percentage in 18 decimals
        uint256 oneMinusT = 1e18 - t;

        // Calculate x^(1-t) and y^(1-t) (x and y are reserveRA and reserveCT)
        uint256 xTerm = power(raReserve, oneMinusT);
        uint256 yTerm = power(ctReserve, oneMinusT);

        // Invariant k is x^(1-t) + y^(1-t)
        k = xTerm + yTerm;
    }

    // Simplified power function to calculate base^exp in 18 decimal precision
    function power(uint256 base, uint256 exp) internal pure returns (uint256 result) {
        result = 1e18; // Start with 1 in 18 decimal precision
        for (uint256 i = 0; i < exp / 1e18; i++) {
            result = (result * base) / 1e18;
        }
    }
}
