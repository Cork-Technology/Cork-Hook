pragma solidity ^0.8.0;

import "./../../Helper.sol";
import {PoolState} from "./../../../src/CorkHook.sol";

contract RemoveLiquidityTest is TestHelper {
    function setUp() external {
        setupTest();

        token0.mint(DEFAULT_ADDRESS, 1000 ether);
        token1.mint(DEFAULT_ADDRESS, 900 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), 1000 ether);
        token1.approve(address(hook), 900 ether);

        vm.stopPrank();
    }

    function test_removeLiquidityBasicPartial() public {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        (,, uint256 mintedLp) =
            hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        LiquidityToken lpToken = LiquidityToken(hook.getLiquidityToken(address(token0), address(token1)));

        uint256 expectedLpApprox = 948.6832 ether;

        vm.assertEq(lpToken.balanceOf(DEFAULT_ADDRESS), mintedLp);
        vm.assertApproxEqAbs(mintedLp, expectedLpApprox, 0.0001 ether);

        uint256 liquidityAmount = 100 ether;
        lpToken.approve(address(hook), liquidityAmount);
        (uint256 amountRa, uint256 amountCt) =
            hook.removeLiquidity(address(token0), address(token1), liquidityAmount, 0, 0, block.timestamp);

        uint256 raBalance = token0.balanceOf(DEFAULT_ADDRESS);
        uint256 ctBalance = token1.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(raBalance, amountRa);
        vm.assertEq(ctBalance, amountCt);
    }

    function test_removeLiquidityBasicFull() public {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        (,, uint256 mintedLp) =
            hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);

        LiquidityToken lpToken = LiquidityToken(hook.getLiquidityToken(address(token0), address(token1)));
        uint256 expectedLpApprox = 948.6832 ether;

        vm.assertEq(lpToken.balanceOf(DEFAULT_ADDRESS), mintedLp);
        vm.assertApproxEqAbs(mintedLp, expectedLpApprox, 0.0001 ether);

        uint256 liquidityAmount = mintedLp;
        lpToken.approve(address(hook), liquidityAmount);
        (uint256 amountRa, uint256 amountCt) =
            hook.removeLiquidity(address(token0), address(token1), liquidityAmount, 0, 0, block.timestamp);

        uint256 raBalance = token0.balanceOf(DEFAULT_ADDRESS);
        uint256 ctBalance = token1.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(raBalance, amountRa);
        vm.assertEq(ctBalance, amountCt);
    }

    function testRevert_deadlineReached() external {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        (,, uint256 mintedLp) =
            hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);

        LiquidityToken lpToken = LiquidityToken(hook.getLiquidityToken(address(token0), address(token1)));
        uint256 expectedLpApprox = 948.6832 ether;

        vm.assertEq(lpToken.balanceOf(DEFAULT_ADDRESS), mintedLp);
        vm.assertApproxEqAbs(mintedLp, expectedLpApprox, 0.0001 ether);

        uint256 liquidityAmount = 100 ether;
        lpToken.approve(address(hook), liquidityAmount);

        vm.expectRevert();
        hook.removeLiquidity(address(token0), address(token1), liquidityAmount, 0, 0, block.timestamp - 1);
    }

    function testRevert_NotInitialized() external {
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 liquidityAmount = 100 ether;

        vm.expectRevert();
        hook.removeLiquidity(address(token0), address(token1), liquidityAmount, 0, 0, block.timestamp);
    }
}
