pragma solidity ^0.8.0;

import "./../../Helper.sol";

contract AddLiquidityTest is TestHelper {
    function setUp() external {
        setupTest();

        token0.mint(DEFAULT_ADDRESS, 10000 ether);
        token1.mint(DEFAULT_ADDRESS, 10000 ether);

        token0.approve(address(hook), 10000 ether);
        token1.approve(address(hook), 10000 ether);
    }

    function test_addLiquidity() public {
        withInitializedPool();
        vm.startPrank(DEFAULT_ADDRESS);

        hook.addLiquidity(address(token0), address(token1), 1000 ether, 900 ether);
    }

    function testRevert_NotInitialized() external {}
}
