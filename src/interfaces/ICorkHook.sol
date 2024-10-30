pragma solidity ^0.8.0;

import "v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import "v4-periphery/src/base/SafeCallback.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import "./IErrors.sol";

interface ICorkHook is IErrors {
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn);

    function addLiquidity(address ra, address ct, uint256 raAmount, uint256 ctAmount)
        external
        returns (uint256 mintedLp);

    function removeLiquidity(address ra, address ct, uint256 liquidityAmount)
        external
        returns (uint256 amountRa, uint256 amountCt);

    function getLiquidityToken(address ra, address ct) external view returns (address);

    function getReserves(address ra, address ct) external view returns (uint256, uint256);

    function getFee(address ra, address ct)
        external
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage);

    function getAmountIn(address ra, address ct, bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function getAmountOut(address ra, address ct, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function getPoolKey(address ra, address ct) external view returns (PoolKey memory);
}