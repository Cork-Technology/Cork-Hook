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

    function test_exactInSwap() external {
        hook.swap(address(token0), address(token1), xIn, 0, bytes(""));
    }

    function test_exactOutSwap() external {}
}
