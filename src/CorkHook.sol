// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import "v4-periphery/lib/v4-core/src/types/PoolId.sol";
import "v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import "v4-periphery/lib/v4-core/src/types/Currency.sol";
import "v4-periphery/src/base/hooks/BaseHook.sol";
import "./lib/State.sol";

// abstract for now
contract CorkHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    error DisableAddLiquidity();

    /// @notice Pool state
    /// @dev amm/pool Id => dsId => PoolState
    mapping(AmmId => mapping(uint256 => PoolState)) internal pool;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true, // override, only allow adding liquidity from the hook
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, // override, only allow removing liquidity from the hook
            afterRemoveLiquidity: false,
            beforeSwap: true, // override, use our price curve
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert DisableAddLiquidity();
    }
}
