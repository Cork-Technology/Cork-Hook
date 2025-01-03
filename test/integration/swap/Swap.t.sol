pragma solidity ^0.8.0;

import "./../../Helper.sol";
import "./../../../src/Constants.sol";
import "./../../../src/interfaces/CorkSwapCallback.sol";
import "v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";
import "./../../../src/lib/MarketSnapshot.sol";
import "Depeg-swap/contracts/libraries/TransferHelper.sol";

contract SwapTest is TestHelper {
    uint256 internal xReserve = 1000 ether;
    uint256 internal yReserve = 1050 ether;

    uint256 internal xIn = 0.99999 ether;
    uint256 internal yOut = 1.04395224 ether;

    uint256 internal start = 0;
    uint256 internal end = 30 days;

    FlashSwapTest flashSwapTest;

    function setUp() public virtual {
        vm.warp(0);
        setupTest();
        withInitializedPool();
        thenAddLiquidity(xReserve, yReserve);

        flashSwapTest = new FlashSwapTest(address(poolManager), address(hook));

        // since we want to get 0.9 of T
        vm.warp(3 days);
    }

    function setupDifferentDecimals(uint8 decimals0, uint8 decimals1) internal {
        decimals0 = uint8(bound(decimals0, 6, 32));
        decimals1 = uint8(bound(decimals1, 6, 32));

        vm.warp(0);
        setupTestWithDifferentDecimals(decimals0, decimals1);
        withInitializedPool();

        uint256 amount0 = TransferHelper.fixedToTokenNativeDecimals(xReserve, token0);
        uint256 amount1 = TransferHelper.fixedToTokenNativeDecimals(yReserve, token1);

        thenAddLiquidity(amount0, amount1);
        flashSwapTest = new FlashSwapTest(address(poolManager), address(hook));

        xIn = TransferHelper.fixedToTokenNativeDecimals(xIn, token0);
        yOut = TransferHelper.fixedToTokenNativeDecimals(yOut, token1);

        // since we want to get 0.9 of T
        vm.warp(3 days);
    }

    function expiry() internal pure override returns (uint256) {
        return 30 days;
    }

    function test_exactInSwapFromCore() public {
        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), type(uint240).max);
        token1.approve(address(swapRouter), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(true, -int256(xIn), Constants.SQRT_PRICE_1_1);

        swapRouter.swap(
            hook.getPoolKey(address(token0), address(token1)),
            params,
            PoolSwapTest.TestSettings(false, false),
            bytes("")
        );

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertApproxEqAbs(balanceAfterToken1 - balanceBeforeToken1, yOut, 0.0001 ether);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.00001 ether);
    }

    function test_exactInSwapFromCoreWithFee() public {
        uint256 feePercentage = 1 ether;
        updateHookFee(feePercentage);

        uint256 splitPercentage = 10 ether;
        updateTreasurySplitPercentage(splitPercentage);

        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), type(uint240).max);
        token1.approve(address(swapRouter), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(true, -int256(xIn), Constants.SQRT_PRICE_1_1);

        swapRouter.swap(
            hook.getPoolKey(address(token0), address(token1)),
            params,
            PoolSwapTest.TestSettings(false, false),
            bytes("")
        );

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertApproxEqAbs(balanceAfterToken1 - balanceBeforeToken1, yOut, 0.01 ether);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.01 ether);

        uint256 treasuryBalance = token0.balanceOf(DEFAULT_TREASURY);

        vm.assertApproxEqAbs(treasuryBalance, 0.0009 ether, 0.0001 ether);
    }

    function testFuzz_exactInSwapFromCore(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);

        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), type(uint240).max);
        token1.approve(address(swapRouter), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(true, -int256(xIn), Constants.SQRT_PRICE_1_1);

        swapRouter.swap(
            hook.getPoolKey(address(token0), address(token1)),
            params,
            PoolSwapTest.TestSettings(false, false),
            bytes("")
        );

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.0001 ether, token1);
        vm.assertApproxEqAbs(balanceAfterToken1 - balanceBeforeToken1, yOut, acceptableError);

        acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.00001 ether, token0);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, acceptableError);
    }

    function test_exactOutSwapFromHook() public {
        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        hook.swap(address(token0), address(token1), 0, yOut, bytes(""));

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.00001 ether);
    }

    function test_exactOutSwapFromHookWithFee() public {
        uint256 feePercentage = 1 ether;
        updateHookFee(feePercentage);

        uint256 splitPercentage = 10 ether;
        updateTreasurySplitPercentage(splitPercentage);

        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        hook.swap(address(token0), address(token1), 0, yOut, bytes(""));

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.1 ether);

        uint256 treasuryBalance = token0.balanceOf(DEFAULT_TREASURY);

        vm.assertApproxEqAbs(treasuryBalance, 0.0009 ether, 0.0001 ether);
    }

    function testFuzz_exactOutSwapFromHook(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);

        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        uint256 balanceBeforeToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceBeforeToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        hook.swap(address(token0), address(token1), 0, yOut, bytes(""));

        uint256 balanceAfterToken1 = token1.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceAfterToken0 = token0.balanceOf(DEFAULT_ADDRESS);

        vm.stopPrank();

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.00001 ether, token0);

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, acceptableError);
    }

    function test_exactOutSwapFromCore() public {
        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), type(uint240).max);
        token1.approve(address(swapRouter), type(uint240).max);

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

    function testFuzz_exactOutSwapFromCore(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);
        token0.mint(DEFAULT_ADDRESS, type(uint240).max);
        token1.mint(DEFAULT_ADDRESS, type(uint240).max);

        vm.startPrank(DEFAULT_ADDRESS);

        // approve the router to spend
        token0.approve(address(swapRouter), type(uint240).max);
        token1.approve(address(swapRouter), type(uint240).max);

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

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.00001 ether, token0);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, acceptableError);
    }

    function test_FlashSwapFromHookExactOutZeroForOne() public {
        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token0), address(token1), 0, yOut, bytes(""), true);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, 0.00001 ether);
    }

    function testFuzz_FlashSwapFromHookExactOutZeroForOne(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);

        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token0), address(token1), 0, yOut, bytes(""), true);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken1 - balanceBeforeToken1, yOut);

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.00001 ether, token0);
        vm.assertApproxEqAbs(balanceBeforeToken0 - balanceAfterToken0, xIn, acceptableError);
    }

    function test_flashSwapFromHookSamePayment() public {
        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token1), address(token0), 0, xIn, bytes(""), false);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken0 - balanceBeforeToken0, xIn);
        vm.assertApproxEqAbs(balanceBeforeToken1 - balanceAfterToken1, yOut, 0.002 ether);
    }

    function testFuzz_flashSwapFromHookSamePayment(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);

        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token1), address(token0), 0, xIn, bytes(""), false);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken0 - balanceBeforeToken0, xIn);

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.002 ether, token1);
        vm.assertApproxEqAbs(balanceBeforeToken1 - balanceAfterToken1, yOut, acceptableError);
    }

    function test_FlashSwapFromHookExactOutOneForZero() public {
        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token1), address(token0), 0, xIn, bytes(""), true);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken0 - balanceBeforeToken0, xIn);
        vm.assertApproxEqAbs(balanceBeforeToken1 - balanceAfterToken1, yOut, 0.002 ether);
    }

    function testFuzz_FlashSwapFromHookExactOutOneForZero(uint8 decimals0, uint8 decimals1) public {
        setupDifferentDecimals(decimals0, decimals1);

        token0.mint(address(flashSwapTest), type(uint240).max);
        token1.mint(address(flashSwapTest), type(uint240).max);

        vm.startPrank(address(flashSwapTest));

        token0.approve(address(hook), type(uint240).max);
        token1.approve(address(hook), type(uint240).max);

        vm.stopPrank();

        uint256 balanceBeforeToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceBeforeToken0 = token0.balanceOf(address(flashSwapTest));

        flashSwapTest.exactOutHook(address(token1), address(token0), 0, xIn, bytes(""), true);

        uint256 balanceAfterToken1 = token1.balanceOf(address(flashSwapTest));
        uint256 balanceAfterToken0 = token0.balanceOf(address(flashSwapTest));

        vm.assertEq(balanceAfterToken0 - balanceBeforeToken0, xIn);

        uint256 acceptableError = TransferHelper.fixedToTokenNativeDecimals(0.002 ether, token1);
        vm.assertApproxEqAbs(balanceBeforeToken1 - balanceAfterToken1, yOut, acceptableError);
    }

    function test_snapshot() public {
        MarketSnapshot memory snapshot = hook.getMarketSnapshot(address(token0), address(token1));
        vm.assertEq(snapshot.reserveRa, xReserve);
        vm.assertEq(snapshot.reserveCt, yReserve);
        vm.assertEq(snapshot.oneMinusT, 0.1 ether);
    }
}

contract FlashSwapTest is CorkSwapCallback {
    address poolManager;
    address hook;

    constructor(address _poolManager, address _hook) {
        poolManager = _poolManager;
        hook = _hook;
    }

    function exactOutHook(
        address ra,
        address ct,
        uint256 amountRaOut,
        uint256 amountCtOut,
        bytes calldata data,
        bool counterPayment
    ) public {
        bytes memory _data = bytes.concat(abi.encode(counterPayment), data);

        CorkHook(hook).swap(ra, ct, amountRaOut, amountCtOut, _data);
    }

    function CorkCall(
        address sender,
        bytes calldata data,
        uint256 paymentAmount,
        address paymentToken,
        address _poolManager
    ) public {
        {
            // make sure only authorized caller can call this(hook, forwarder, and the router)
            require(
                msg.sender == address(hook) || msg.sender == address(CorkHook(hook).getForwarder()), "Invalid caller"
            );
            require(sender == address(this), "invalid sender");
        }

        // to test, we just unconditionally pay the pool manager
        Asset(paymentToken).transfer(_poolManager, paymentAmount);
    }
}
