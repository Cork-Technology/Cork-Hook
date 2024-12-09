pragma solidity ^0.8.20;

import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import "./Constants.sol";
import "./lib/Calls.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "./interfaces/CorkSwapCallback.sol";
import "./lib/SenderSlot.sol";
import "./interfaces/IErrors.sol";

/// @title PoolInitializer
/// workaround contract to auto initialize pool & swap when adding liquidity since uni v4 doesn't support self calling from hook
contract HookForwarder is Ownable, CorkSwapCallback, IErrors {
    using CurrencyLibrary for Currency;

    IPoolManager poolManager;

    constructor(IPoolManager _poolManager) Ownable(msg.sender) {
        poolManager = _poolManager;
    }

    modifier clearSenderAfter() {
        _;
        SenderSlot.clear();
    }

    function initializePool(address token0, address token1) external onlyOwner {
        PoolKey memory key = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            Constants.FEE,
            Constants.TICK_SPACING,
            IHooks(owner())
        );

        poolManager.initialize(key, Constants.SQRT_PRICE_1_1);
    }

    function swap(SwapParams calldata params) external onlyOwner {
        SenderSlot.set(params.sender);

        address token0 = Currency.unwrap(params.poolKey.currency0);
        address token1 = Currency.unwrap(params.poolKey.currency1);

        poolManager.swap(params.poolKey, params.params, params.swapData);
    }

    /// @notice actually transfer token to user, this is needed in case of when user directly swap using hook
    /// the logic is inside the hook, but here it act on behalf of the user by settling the swap and transferring the token to the user
    /// should only be called after swap or before executing callback and MUST be called only once throughout the entire swap lifecycle
    function forwardToken(Currency _in, Currency out, uint256 amountIn, uint256 amountOut)
        external
        onlyOwner
        clearSenderAfter
    {
        // get sender from slot
        address to = SenderSlot.get();

        if (to == address(0)) {
            revert IErrors.NoSender();
        }

        CurrencySettler.take(out, poolManager, to, amountOut, false);
        CurrencySettler.settle(_in, poolManager, address(this), amountIn, false);
    }

    function getCurrentSender() external view returns (address) {
        return SenderSlot.get();
    }

    /// @notice forward token without clearing the sender, MUST only be called before executing flash swap callback and ONLY ONCE in the entire swap lifecycle
    /// this is needed in case of when user directly swap using hook
    function forwardTokenUncheked(Currency out, uint256 amountOut) external onlyOwner {
        address sender = SenderSlot.get();

        if (sender == address(0)) {
            revert IErrors.NoSender();
        }

        CurrencySettler.take(out, poolManager, sender, amountOut, false);
    }

    /// @notice we're just forwarding the call to the callback contract
    function CorkCall(address sender, bytes calldata data, uint256 paymentAmount, address paymentToken, address pm)
        external
        onlyOwner
        clearSenderAfter
    {
        if (sender != address(this)) {
            revert IErrors.OnlySelfCall();
        }

        // we set the sender to the original sender.
        sender = SenderSlot.get();

        if (sender == address(0)) {
            revert IErrors.NoSender();
        }

        poolManager.sync(Currency.wrap(paymentToken));

        CorkSwapCallback(sender).CorkCall(sender, data, paymentAmount, paymentToken, pm);

        poolManager.settle();
    }
}
