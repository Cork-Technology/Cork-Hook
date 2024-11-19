pragma solidity ^0.8.0;

import "./../../../src/lib/SwapMath.sol";
import "forge-std/Test.sol";

contract SwapMathTest is Test {
    uint256 internal constant start = 0;
    uint256 internal constant end = 30 days;

    uint256 internal constant xReserve = 1000 ether;
    uint256 internal constant yReserve = 1050 ether;
    uint256 internal constant xIn = 1 ether;
    uint256 internal constant yOut = 1.04395224 ether;

    function test_amountInWithoutFee() external pure {
        // so that we get 0.9 t
        uint256 current = 3 days;

        uint256 _1MinT = SwapMath.oneMinusT(start, end, current);

        vm.assertEq(_1MinT, 0.1 ether);

        uint256 _in = SwapMath.getAmountIn(yOut, xReserve, yReserve, _1MinT, 0);

        vm.assertApproxEqAbs(_in, xIn, 0.00001 ether);
    }

    function test_amountInWithFee() external pure {
        // so that we get 0.9 t
        uint256 current = 3 days;

        uint256 _1MinT = SwapMath.oneMinusT(start, end, current);

        vm.assertEq(_1MinT, 0.1 ether);

        //  1% fee
        uint256 fee = 1 ether;

        uint256 _in = SwapMath.getAmountIn(yOut, xReserve, yReserve, _1MinT, fee);

        vm.assertApproxEqAbs(_in, xIn + 0.009 ether, 0.001 ether);
    }

    function test_amountOutWithoutFee() external pure {
        // so that we get 0.9 t
        uint256 current = 3 days;

        uint256 _1MinT = SwapMath.oneMinusT(start, end, current);

        vm.assertEq(_1MinT, 0.1 ether);

        uint256 _out = SwapMath.getAmountOut(xIn, xReserve, yReserve, _1MinT, 0);

        vm.assertApproxEqAbs(_out, yOut, 0.00001 ether);
    }

    function test_amountOutWithFee() external pure {
        // so that we get 0.9 t
        uint256 current = 3 days;

        uint256 _1MinT = SwapMath.oneMinusT(start, end, current);

        vm.assertEq(_1MinT, 0.1 ether);

        //  1% fee
        uint256 fee = 1 ether;

        uint256 _out = SwapMath.getAmountOut(xIn, xReserve, yReserve, _1MinT, fee);

        vm.assertApproxEqAbs(_out, yOut - 0.009 ether, 0.001 ether);
    }

    function test_inOutParity() external {
        // so that we get 0.9 t
        uint256 current = 3 days;

        uint256 _1MinT = SwapMath.oneMinusT(start, end, current);

        vm.assertEq(_1MinT, 0.1 ether);

        uint256 initOut = SwapMath.getAmountOut(xIn, xReserve, yReserve, _1MinT, 0);
        uint256 initIn = SwapMath.getAmountIn(initOut, xReserve, yReserve, _1MinT, 0);

        uint256 out = SwapMath.getAmountOut(initIn, xReserve, yReserve, _1MinT, 0);
        vm.assertApproxEqAbs(initOut, out, 0.000000001 ether);

        uint256 in_ = SwapMath.getAmountIn(initOut, xReserve, yReserve, _1MinT, 0);
        vm.assertApproxEqAbs(initIn, in_, 0.000000001 ether);
    }

    function test_normalizedTime() external pure {
        uint256 current = 0;

        uint256 normalizedTime = SwapMath.getNormalizedTimeToMaturity(start, end, current);
        vm.assertApproxEqAbs(normalizedTime, 0.9999 ether, 0.0001 ether);

        current = 15 days;
        normalizedTime = SwapMath.getNormalizedTimeToMaturity(start, end, current);
        vm.assertEq(normalizedTime, 0.5 ether);

        current = 30 days;
        normalizedTime = SwapMath.getNormalizedTimeToMaturity(start, end, current);
        vm.assertEq(normalizedTime, 0 ether);
    }

    function test_minT() external pure {
        uint256 current = 0;

        uint256 minT = SwapMath.oneMinusT(start, end, current);
        // wont be exactly 0 since we add 1 to the elapsed time if it's 0
        vm.assertEq(minT, 0.000000385802469135 ether);

        current = 3 days;
        minT = SwapMath.oneMinusT(start, end, current);
        vm.assertEq(minT, 0.1 ether);

        current = 15 days;
        minT = SwapMath.oneMinusT(start, end, current);
        vm.assertEq(minT, 0.5 ether);

        current = 30 days;
        minT = SwapMath.oneMinusT(start, end, current);
        vm.assertEq(minT, 1 ether);
    }

    function test_feePercentage() external pure {
        uint256 current = 0;
        // 1%
        uint256 baseFee = 1 ether;

        uint256 feePercentage = SwapMath.getFeePercentage(baseFee, start, end, current);
        vm.assertApproxEqAbs(feePercentage, 0.9999 ether, 0.0001 ether);

        current = 3 days;
        feePercentage = SwapMath.getFeePercentage(baseFee, start, end, current);
        vm.assertEq(feePercentage, 0.9 ether);

        current = 15 days;
        feePercentage = SwapMath.getFeePercentage(baseFee, start, end, current);
        vm.assertEq(feePercentage, 0.5 ether);

        current = 30 days;
        feePercentage = SwapMath.getFeePercentage(baseFee, start, end, current);
        vm.assertEq(feePercentage, 0 ether);
    }

    function test_calcPercentage() external pure {
        uint256 base = 100 ether;
        uint256 percentage = 10 ether;

        uint256 result = SwapMath.calculatePercentage(base, percentage);
        vm.assertEq(result, 10 ether);
    }

    function test_getFee() external pure {
        uint256 amount = 100 ether;
        // 1%
        uint256 baseFee = 1 ether;

        uint256 current = 0;

        uint256 fee = SwapMath.getFee(amount, baseFee, start, end, current);
        vm.assertApproxEqAbs(fee, 0.9999 ether, 0.0001 ether);

        current = 15 days;
        fee = SwapMath.getFee(amount, baseFee, start, end, current);
        vm.assertEq(fee, 0.5 ether);

        current = 30 days;

        fee = SwapMath.getFee(amount, baseFee, start, end, current);
        vm.assertEq(fee, 0 ether);
    }

    function test_invariant() external view {
        uint256 reserve0 = 100 ether;
        uint256 reserve1 = 200 ether;

        uint256 current = 0;

        uint256 invariant = SwapMath.getInvariant(reserve0, reserve1, start, end, current);
        vm.assertApproxEqAbs(invariant, 2 ether, 0.0001 ether);
    }
}
