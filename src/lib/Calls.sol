pragma solidity 0.8.26;

enum Action {
    AddLiquidity,
    RemoveLiquidity,
    Swap
}

struct AddLiquidtyParams {
    address token0;
    uint256 amount0;
    address token1;
    uint256 amount1;
    address sender;
}

struct RemoveLiquidtyParams {
    address token0;
    address token1;
    uint256 liquidityAmount;
    address sender;
}
