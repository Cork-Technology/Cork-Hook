pragma solidity ^0.8.0;


/// @notice amm id, must be the same as pool id in cork
type AmmId is bytes32;

struct PoolState {
    uint256 reserveRA;
    uint256 reserveCT;
    address ra;
    address ct;
    // should be deployed using clones
    address liquidityToken;
}

library PoolStateLibrary {
    function initialize(PoolState storage state, address _ra, address _ct, address _liquidityToken) internal {
        state.ra = _ra;
        state.ct = _ct;
        state.liquidityToken = _liquidityToken;
    }

    function isInitialized(PoolState storage state) internal view returns (bool) {
        return state.ra != address(0);
    }
}
