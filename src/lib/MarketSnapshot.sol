pragma solidity ^0.8.20;

import "./SwapMath.sol";

struct MarketSnapshot {
    uint256 reserveRa;
    uint256 reserveCt;
    uint256 oneMinusT;
    uint256 baseFee;
    address liquidityToken;
}

library MarketSnapshotLib {
    function getAmountOut(MarketSnapshot memory self, uint256 amountIn, bool raForCt) internal pure returns (uint256 amountOut) {
        if (raForCt) {
            return SwapMath.getAmountOut(amountIn, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
        } else {
            return SwapMath.getAmountOut(amountIn, self.reserveCt, self.reserveRa, self.oneMinusT, self.baseFee);
        }
    }

    function getAmountIn(MarketSnapshot memory self, uint256 amountOut, bool raForCt) internal pure returns (uint256 amountIn) {
        if (raForCt) {
            return SwapMath.getAmountIn(amountOut, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
        } else {
            return SwapMath.getAmountIn(amountOut, self.reserveCt, self.reserveRa, self.oneMinusT, self.baseFee);
        }
    }
}
