pragma solidity ^0.8.0;

import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import "./Constants.sol";

/// @title PoolInitializer
/// workaround contract to auto initialize pool when adding liquidity since uni v4 doesn't support self calling from hook
contract PoolInitializer is Ownable {

    IPoolManager poolmanager;

    constructor(IPoolManager _poolManager) Ownable(msg.sender) {
        poolmanager = _poolManager;
    }

    function initializePool(address token0, address token1) external onlyOwner {
        PoolKey memory key =
            PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), Constants.FEE, Constants.TICK_SPACING, IHooks(owner()));

        poolmanager.initialize(key, Constants.SQRT_PRICE_1_1);
    }
}
