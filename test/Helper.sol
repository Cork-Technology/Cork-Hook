pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {Deployers} from "v4-periphery/lib/v4-core/test/utils/Deployers.sol";
import "forge-std/mocks/MockERC20.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {CorkHook, LiquidityToken, AmmId, PoolState} from "./../src/CorkHook.sol";
import {TestCorkHook} from "./TestCorkHook.sol";

contract TestHelper is Test, Deployers {
    IPoolManager poolManager;

    DummyErc20 token0;
    DummyErc20 token1;

    LiquidityToken lpBase;
    TestCorkHook hook;

    uint160 flags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG
    );

    address DEFAULT_ADDRESS = address(69);

    function setupTest() public {
        deployFreshManagerAndRouters();

        poolManager = IPoolManager(manager);
        token0 = new DummyErc20();
        token1 = new DummyErc20();

        token0.initialize("Token0", "TK0", 18);
        token1.initialize("Token1", "TK1", 18);

        //sort
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        lpBase = new LiquidityToken();

        deployCodeTo("TestCorkHook.sol", abi.encode(poolManager, lpBase), address(flags));

        hook = TestCorkHook(address(flags));
    }

    function setupWithInitializedPool() public {
        setupTest();
        withInitializedPool();
    }

    function withInitializedPool() public {
        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 1, IHooks(hook));

        poolManager.initialize(key, SQRT_PRICE_1_1);
    }

    function thenAddLiquidity(uint256 amount0, uint256 amount1) public {
        token0.mint(DEFAULT_ADDRESS, amount0);
        token1.mint(DEFAULT_ADDRESS, amount1);

        vm.startPrank(DEFAULT_ADDRESS);
        token0.approve(address(hook), amount0);
        token1.approve(address(hook), amount1);

        hook.addLiquidity(address(token0), address(token1), amount0, amount1);
        vm.stopPrank();
    }
}

contract DummyErc20 is MockERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}
