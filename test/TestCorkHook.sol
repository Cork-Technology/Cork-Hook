pragma solidity ^0.8.0;

import {CorkHook, LiquidityToken, AmmId, PoolState} from "./../src/CorkHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract TestCorkHook is CorkHook {
    constructor(IPoolManager _poolManager, LiquidityToken _lpBase) CorkHook(_poolManager, _lpBase) {}

    function getPoolState(AmmId ammId) public view returns (PoolState memory) {
        return pool[ammId];
    }
}
