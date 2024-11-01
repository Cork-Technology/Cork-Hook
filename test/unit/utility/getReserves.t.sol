pragma solidity ^0.8.0;

import "./../../Helper.sol";
import {PoolState} from "./../../../src/CorkHook.sol";

contract GetReserveTest is TestHelper {
    uint256 internal constant amount0 = 1000 ether;
    uint256 internal constant amount1 = 900 ether;

    function setUp() external {
        setupTest();
        withInitializedPool();

        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), 10000 ether);
        token1.approve(address(hook), 10000 ether);

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);

        vm.stopPrank();
    }

    function test_addLiquidityBasic() public {
        (uint256 token0reserves, uint256 token1reserves) = hook.getReserves(address(token0), address(token1));
        vm.assertEq(token0reserves, amount0);
        vm.assertEq(token1reserves, amount1);

        (token1reserves, token0reserves) = hook.getReserves(address(token1), address(token0));
        vm.assertEq(token0reserves, amount0);
        vm.assertEq(token1reserves, amount1);
    }
}
