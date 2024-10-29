pragma solidity ^0.8.0;

import "./../../Helper.sol";
import "./../../../src/Constants.sol";

contract SwapTest is TestHelper {
    uint256 internal constant xReserve = 1000 ether;
    uint256 internal constant yReserve = 1050 ether;

    uint256 internal constant xIn = 1 ether;
    uint256 internal constant yOut = 1.04395224 ether;

    uint256 internal constant start = 0;
    uint256 internal constant end = 30 days;

    function setUp() public {
        setupTest();
        withInitializedPool();
        thenAddLiquidity(xReserve, yReserve);
    }

    function test_exactInSwap() external {}

    function test_exactOutSwapFromHook() external {
        vm.startPrank(DEFAULT_ADDRESS);
        
        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        hook.swap(address(token0), address(token1), 0, yOut, bytes(""));

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertEq(balanceBeforeToken0 - balanceAfterToken0, xIn);
    }

    function test_exactOutSwapFromCore() external {}
}
