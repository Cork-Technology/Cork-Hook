pragma solidity ^0.8.0;

import "./../../../src/lib/LiquidityMath.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract LiquidityMathTest is Test {
    function test_addLiquidityFirst() external {
        uint256 reserve0 = 0;
        uint256 reserve1 = 0;
        uint256 totalLiquidity = 0;

        // representing 0.1 DS price
        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        (uint256 newReserve0, uint256 newReserve1, uint256 liquidityMinted) =
            LiquidityMath.addLiquidity(reserve0, reserve1, totalLiquidity, amount0, amount1);

        vm.assertEq(newReserve0, amount0);
        vm.assertEq(newReserve1, amount1);

        // sqrt(amount0 * amount1)
        vm.assertApproxEqAbs(liquidityMinted, 948.6832 ether, 0.0001 ether);
    }

    function test_addLiquiditySubsequent() external {
        uint256 reserve0 = 2000 ether;
        uint256 reserve1 = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        (uint256 newReserve0, uint256 newReserve1, uint256 liquidityMinted) =
            LiquidityMath.addLiquidity(reserve0, reserve1, totalLiquidity, amount0, amount1);

        vm.assertEq(newReserve0, amount0 + reserve0);
        vm.assertEq(newReserve1, amount1 + reserve1);

        vm.assertApproxEqAbs(liquidityMinted, 474.3416491 ether, 0.0001 ether);
    }

    function test_removeLiquidity() external {
        uint256 reserve0 = 2000 ether;
        uint256 reserve1 = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 100 ether;
        (
            uint256 amount0, // Amount of RA returned to the LP
            uint256 amount1, // Amount of CT returned to the LP
            uint256 newReserve0, // Updated reserve of RA
            uint256 newReserve1 // Updated reserve of CT
        ) = LiquidityMath.removeLiquidity(reserve0, reserve1, totalLiquidity, liquidityAmount);

        vm.assertApproxEqAbs(amount0, 210.818 ether, 0.001 ether);
        vm.assertApproxEqAbs(amount1, 189.736 ether, 0.001 ether);
        vm.assertEq(newReserve0, 2000 ether - amount0);
        vm.assertEq(newReserve1, 1800 ether - amount1);

        liquidityAmount = totalLiquidity;

        (
            amount0, // Amount of RA returned to the LP
            amount1, // Amount of CT returned to the LP
            newReserve0, // Updated reserve of RA
            newReserve1 // Updated reserve of CT
        ) = LiquidityMath.removeLiquidity(reserve0, reserve1, totalLiquidity, liquidityAmount);

        vm.assertEq(amount0, 2000 ether);
        vm.assertEq(amount1, 1800 ether);
        vm.assertEq(newReserve0, 0);
        vm.assertEq(newReserve1, 0);
    }

    function testRevert_removeLiquidityInvalidLiquidity() external {
        uint256 reserve0 = 2000 ether;
        uint256 reserve1 = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 0;

        vm.expectRevert();
        LiquidityMath.removeLiquidity(reserve0, reserve1, totalLiquidity, liquidityAmount);
    }

    function testRevert_removeLiquidityNoLiquidity() external {
        uint256 reserve0 = 2000 ether;
        uint256 reserve1 = 1800 ether;
        uint256 totalLiquidity = 0;

        uint256 liquidityAmount = 100 ether;

        vm.expectRevert();
        LiquidityMath.removeLiquidity(reserve0, reserve1, totalLiquidity, liquidityAmount);
    }

    function testFuzz_proportionalAmount(uint256 amount0) external {
        amount0 = bound(amount0, 1 ether, 100000 ether);

        uint256 reserve0 = 1000 ether;
        uint256 reserve1 = 2000 ether;

        uint256 amount1 = LiquidityMath.getProportionalAmount(amount0, reserve0, reserve1);

        vm.assertEq(amount1, amount0 * 2);
    }

    function test_dustInferOptimalAmount() external {
        uint256 amount0Desired = 1 ether;

        uint256 amount1Desired = 5 ether;

        uint256 reserve0 = 1000 ether;
        uint256 reserve1 = 2000 ether;

        (uint256 amount0, uint256 amount1) =
            LiquidityMath.inferOptimalAmount(reserve0, reserve1, amount0Desired, amount1Desired, 0, 0);

        // we only use 2 ether
        vm.assertEq(amount1, 2 ether);

        amount1Desired = 0.5 ether;

        (amount0, amount1) = LiquidityMath.inferOptimalAmount(reserve0, reserve1, amount0Desired, amount1Desired, 0, 0);

        // we only use 0.25 ether
        vm.assertEq(amount0, 0.25 ether);
        vm.assertEq(amount1, amount1Desired);
    }
}
