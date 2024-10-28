pragma solidity ^0.8.0;

import "./LiquidityMath.sol";
import "./../LiquidityToken.sol";
import "v4-periphery/lib/v4-core/src/types/Currency.sol";
import "./balancers/FixedPoint.sol";

/// @notice amm id,
type AmmId is bytes32;

function toAmmId(address ra, address ct) pure returns (AmmId) {
    (address token0, address token1) = sort(ra, ct);

    return AmmId.wrap(keccak256(abi.encodePacked(token0, token1)));
}

function toAmmId(Currency _ra, Currency _ct) pure returns (AmmId) {
    (address ra, address ct) = (Currency.unwrap(_ra), Currency.unwrap(_ct));

    return toAmmId(ra, ct);
}

function sort(address a, address b) pure returns (address, address) {
    return a < b ? (a, b) : (b, a);
}

function reverseSortWithAmount(address a, address b, address token0, address token1, uint256 amount0, uint256 amount1)
    pure
    returns (address, address, uint256, uint256)
{
    return a == token0 ? (token0, token1, amount0, amount1) : (token1, token0, amount1, amount0);
}

function sort(address a, address b, uint256 amountA, uint256 amountB)
    pure
    returns (address, address, uint256, uint256)
{
    return a < b ? (a, b, amountA, amountB) : (b, a, amountB, amountA);
}

struct PoolState {
    uint256 reserve0;
    uint256 reserve1;
    address token0;
    address token1;
    // should be deployed using clones
    LiquidityToken liquidityToken;
    // base fee in 18 decimals, 1% is 1e18\
    uint256 fee;
}

library PoolStateLibrary {
    uint256 constant MAX_FEE = FixedPoint.ONE * 100;

    function ensureLiquidityEnough(PoolState storage state, uint256 amountOut, address token) internal view {
        if (token == state.token0 && state.reserve0 < amountOut) {
            revert("Not enough liquidity");
        } else if (token == state.token1 && state.reserve1 < amountOut) {
            revert("Not enough liquidity");
        } else {
            // TODO : move to interface
            revert("Token not in pool");
        }
    }

    function updateReserves(PoolState storage state, address token, uint256 amount, bool minus) internal {
        if (token == state.token0) {
            state.reserve0 = minus ? state.reserve0 - amount : state.reserve0 + amount;
        } else if (token == state.token1) {
            state.reserve1 = minus ? state.reserve1 - amount : state.reserve1 + amount;
        } else {
            // TODO : move to interface
            revert("Token not in pool");
        }
    }

    function updateFee(PoolState storage state, uint256 fee) internal {
        // TODO : move to interface
        require(fee <= MAX_FEE, "Fee too high");
        state.fee = fee;
    }

    function getToken0(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token0);
    }

    function getToken1(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token1);
    }

    function initialize(PoolState storage state, address _token0, address _token1, address _liquidityToken) internal {
        state.token0 = _token0;
        state.token1 = _token1;
        state.liquidityToken = LiquidityToken(_liquidityToken);
    }

    function isInitialized(PoolState storage state) internal view returns (bool) {
        return state.token0 != address(0);
    }

    function tryAddLiquidity(PoolState storage state, uint256 amount0, uint256 amount1)
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp)
    {
        (reserve0, reserve1, mintedLp) = LiquidityMath.addLiquidity(
            state.reserve0, state.reserve1, state.liquidityToken.totalSupply(), amount0, amount1
        );
    }

    function addLiquidity(PoolState storage state, uint256 amount0, uint256 amount1, address sender)
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp)
    {
        (reserve0, reserve1, mintedLp) = tryAddLiquidity(state, amount0, amount1);

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.mint(sender, mintedLp);
    }

    function tryRemoveLiquidity(PoolState storage state, uint256 liquidityAmount)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = LiquidityMath.removeLiquidity(
            state.reserve0, state.reserve1, state.liquidityToken.totalSupply(), liquidityAmount
        );
    }

    function removeLiquidity(PoolState storage state, uint256 liquidityAmount, address sender)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = tryRemoveLiquidity(state, liquidityAmount);

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.burnFrom(sender, liquidityAmount);
    }
}
