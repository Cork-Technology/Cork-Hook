pragma solidity ^0.8.0;

import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

/// @title PoolInitializer
/// workaround contract to auto initialize pool when adding liquidity since uni v4 doesn't support self calling from hook
contract PoolInitializer is Ownable {
    // we will use our own fee, no need for uni v4 fee
    uint24 public constant FEE = 0;
    // default tick spacing since we don't actually use it, so we just set it to 1
    int24 public constant TICK_SPACING = 1;
    // default sqrt price, we don't really use this one either
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    IPoolManager poolmanager;

    constructor(IPoolManager _poolManager) Ownable(msg.sender) {
        poolmanager = _poolManager;
    }

    function initializePool(address token0, address token1) external onlyOwner {
        PoolKey memory key =
            PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), FEE, TICK_SPACING, IHooks(owner()));

        poolmanager.initialize(key, SQRT_PRICE_1_1);
    }
}
