pragma solidity ^0.8.0;

import "./../../Helper.sol";
import {PoolState} from "./../../../src/CorkHook.sol";
import "Depeg-swap/contracts/libraries/TransferHelper.sol";

contract AddLiquidityTest is TestHelper {
    function setUp() external {
        setupTest();

        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), 10000 ether);
        token1.approve(address(hook), 10000 ether);

        vm.stopPrank();
    }

    function setupDifferentDecimals(uint8 decimals0, uint8 decimals1) internal returns (uint8, uint8) {
        decimals0 = uint8(bound(decimals0, 6, 32));
        decimals1 = uint8(bound(decimals1, 6, 32));

        setupTestWithDifferentDecimals(decimals0, decimals1);
        withInitializedPool();

        token0.mint(DEFAULT_ADDRESS, type(uint256).max);
        token1.mint(DEFAULT_ADDRESS, type(uint256).max);

        vm.startPrank(DEFAULT_ADDRESS);
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
        vm.stopPrank();

        return (decimals0, decimals1);
    }

    function test_addLiquidityBasic() public {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        PoolState memory state = hook.getPoolState(address(token0), address(token1));

        vm.assertEq(state.reserve0, amount0);
        vm.assertEq(state.reserve1, amount1);
        vm.assertApproxEqAbs(state.liquidityToken.totalSupply(), 948.6832 ether, 0.0001 ether);
    }

    function testFuzz_addLiquidityBasic(uint8 decimals0, uint8 decimals1) public {
        (decimals0, decimals1) = setupDifferentDecimals(decimals0, decimals1);
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = TransferHelper.normalizeDecimals(1000 ether, DEFAULT_DECIMALS, decimals0);
        uint256 amount1 = TransferHelper.normalizeDecimals(900 ether, DEFAULT_DECIMALS, decimals1);

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        PoolState memory state = hook.getPoolState(address(token0), address(token1));

        vm.assertEq(state.reserve0, amount0);
        vm.assertEq(state.reserve1, amount1);

        vm.assertApproxEqAbs(state.liquidityToken.totalSupply(), 948.6832 ether, 0.0001 ether);
    }

    function test_dustUnOptimalAmountBasic() public {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 2000 ether;

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        PoolState memory state = hook.getPoolState(address(token0), address(token1));

        amount0 = 1 ether;
        amount1 = 3 ether;

        (uint256 used0, uint256 used1,) =
            hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);

        vm.assertEq(used0, 1 ether);
        vm.assertEq(used1, 2 ether);
    }

    function testFuzz_dustUnOptimalAmountBasic(uint8 decimals0, uint8 decimals1) public {
        (decimals0, decimals1) = setupDifferentDecimals(decimals0, decimals1);
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = TransferHelper.normalizeDecimals(1000 ether, DEFAULT_DECIMALS, decimals0);
        uint256 amount1 = TransferHelper.normalizeDecimals(2000 ether, DEFAULT_DECIMALS, decimals1);

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        PoolState memory state = hook.getPoolState(address(token0), address(token1));

        amount0 = TransferHelper.normalizeDecimals(1 ether, DEFAULT_DECIMALS, decimals0);
        amount1 = TransferHelper.normalizeDecimals(3 ether, DEFAULT_DECIMALS, decimals1);

        (uint256 used0, uint256 used1,) =
            hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);

        vm.assertEq(used0, TransferHelper.normalizeDecimals(1 ether, DEFAULT_DECIMALS, decimals0));
        vm.assertEq(used1, TransferHelper.normalizeDecimals(2 ether, DEFAULT_DECIMALS, decimals1));
    }

    function test_AddLiquidityNotInitialized() external {
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
    }

    function testRevert_notWithinDeadline() external {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 900 ether;

        vm.expectRevert();
        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp - 1);
    }
}
