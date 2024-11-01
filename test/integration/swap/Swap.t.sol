pragma solidity ^0.8.0;

import "./../../Helper.sol";
import "./../../../src/Constants.sol";

import "v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

contract SwapTest is TestHelper {
    uint256 internal constant xReserve = 1000 ether;
    uint256 internal constant yReserve = 1050 ether;

    uint256 internal constant xIn = 0.99999 ether;
    uint256 internal constant yOut = 1.04395224 ether;

    uint256 internal constant start = 0;
    uint256 internal constant end = 30 days;

    function setUp() public {
        vm.warp(0);
        setupTest();
        withInitializedPool();
        thenAddLiquidity(xReserve, yReserve);

        // since we want to get 0.9 of T
        vm.warp(3 days);
    }

    function expiry() internal pure override returns (uint256) {
        return 30 days;
    }

    // TODO
    function test_exactInSwapFromCore() external {}

    function test_exactOutSwapFromHook() external {
        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), 10000 ether);
        token1.approve(address(hook), 10000 ether);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        hook.swap(address(token0), address(token1), 0, yOut, bytes(""));

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.00001 ether);
    }

    function testFuzz_SwapExactOutFromHook(uint256 amount) external {
        vm.assume(amount < 100 ether && amount > 1 ether);

        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        // in this case, the hook itself become the router, so we need to approve it
        token0.approve(address(hook), 10000 ether);
        token1.approve(address(hook), 10000 ether);

        hook.swap(address(token0), address(token1), 0, amount, bytes(""));
        hook.swap(address(token0), address(token1), amount, 0, bytes(""));

        vm.stopPrank();
    }

    function test_exactOutSwapFromCore() external {
        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), 10000 ether);
        token1.approve(address(swapRouter), 10000 ether);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(true, int256(yOut), Constants.SQRT_PRICE_1_1);

        swapRouter.swap(
            hook.getPoolKey(address(token0), address(token1)),
            params,
            PoolSwapTest.TestSettings(false, false),
            bytes("")
        );

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.00001 ether);
    }

    // TODO
    function test_FlashSwapFromHookExactOut() external {}

    function test_FlashSwapFromCoreExactIn() external {}

    function test_FlashSwapFromCoreExactOut() external {}
}
