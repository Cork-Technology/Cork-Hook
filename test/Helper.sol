pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {Deployers} from "v4-periphery/lib/v4-core/test/utils/Deployers.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {CorkHook, LiquidityToken, AmmId, PoolState} from "./../src/CorkHook.sol";
import {TestCorkHook} from "./TestCorkHook.sol";
import "Depeg-swap/contracts/core/assets/Asset.sol";

contract TestHelper is Test, Deployers {
    IPoolManager poolManager;

    Asset token0;
    Asset token1;

    LiquidityToken lpBase;
    TestCorkHook hook;

    uint160 flags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    address DEFAULT_ADDRESS = address(69);

    function expiry() internal pure virtual returns (uint256) {
        return 0;
    }

    function setupTest() public {
        deployFreshManagerAndRouters();

        poolManager = IPoolManager(manager);

        token0 = new Asset("AA", "ABAB", address(this), expiry(), 0, 1);
        token1 = new Asset("AA", "ABAB", address(this), expiry(), 0, 1);

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

        hook.addLiquidity(address(token0), address(token1), amount0, amount1, 0, 0, block.timestamp);
        vm.stopPrank();
    }
}
