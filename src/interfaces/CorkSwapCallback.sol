// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface CorkSwapCallback {
    /**
     * @notice a callback function that will be called by the hook when doing swap, intended use case for flash swap
     * @param data the data that will be passed to the callback
     * @param paymentAmount the amount of tokens that the user must approve to be spent by the hook, DO NOT transfer token directly, the hook will takes care of that. the amount will be calculated in respect of your specified token to pay. 
     * @param zeroForOne if true, the user must pay token0, otherwise token1
     */
    function call(bytes calldata data, uint256 paymentAmount, bool zeroForOne) external;
}
