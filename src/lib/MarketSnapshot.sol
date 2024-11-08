pragma solidity ^0.8.0;

import "./SwapMath.sol";

struct MarketSnapshot {
    uint256 reserveRa;
    uint256 reserveCt;
    uint256 oneMinusT;
    uint256 baseFee;
}

library MarketSnapshotLib {
    function getAmountOut(MarketSnapshot memory self, uint256 amountIn) public pure returns (uint256 amountOut) {
        return SwapMath.getAmountOut(amountIn, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
    }

    function getAmountIn(MarketSnapshot memory self, uint256 amountOut) public pure returns (uint256 amountIn) {
        return SwapMath.getAmountIn(amountOut, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
    }
}
