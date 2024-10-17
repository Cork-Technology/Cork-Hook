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

contract TestHelper is Test, Deployers {
    IPoolManager poolManager;

    MockERC20 token0;
    MockERC20 token1;

    LiquidityToken lpBase;
    TestCorkHook hook;

    uint160 flags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG
    );

    function setup() public {
        deployFreshManagerAndRouters();

        poolManager = IPoolManager(manager);
        token0 = new MockERC20();
        token1 = new MockERC20();

        token0.initialize("Token0", "TK0", 18);
        token1.initialize("Token1", "TK1", 18);

        //sort
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        lpBase = new LiquidityToken();
        deployCodeTo("CorkHook.sol", abi.encode(poolManager, lpBase), address(flags));
        
        // etch code with getters
        vm.etch(address(flags), type(TestCorkHook).creationCode);
    }

    function setupWithInitializedPool() public {
        setup();

        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 0, IHooks(hook));

        poolManager.initialize(key, 0);
    }
}

contract TestCorkHook is CorkHook {
    constructor(IPoolManager _poolManager, LiquidityToken _lpBase) CorkHook(_poolManager, _lpBase) {}

    function getPoolState(AmmId ammId) public view returns (PoolState memory) {
        return pool[ammId];
    }
}
