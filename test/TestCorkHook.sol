pragma solidity ^0.8.0;

import {CorkHook, LiquidityToken, AmmId, PoolState} from "./../src/CorkHook.sol";
import {toAmmId} from "./../src/lib/State.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract TestCorkHook is CorkHook {
    constructor(IPoolManager _poolManager, LiquidityToken _lpBase) CorkHook(_poolManager, _lpBase, msg.sender) {}

    function getPoolState(address tokenA, address tokenB) public view returns (PoolState memory) {
        return pool[toAmmId(tokenA, tokenB)];
    }
}
