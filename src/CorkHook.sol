pragma solidity 0.8.26;

// TODO : refactor named imports
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-periphery/lib/v4-core/src/types/PoolId.sol";
import {Currency} from "v4-periphery/lib/v4-core/src/types/Currency.sol";
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import {LiquidityToken} from "./LiquidityToken.sol";
import {Action, AddLiquidtyParams, RemoveLiquidtyParams} from "./lib/Calls.sol";
import "./lib/State.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import "./lib/Calls.sol";
import "./lib/SwapMath.sol";
import "Depeg-swap/contracts/interfaces/IExpiry.sol";
import "./interfaces/CorkSwapCallback.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {HookForwarder} from "./Forwarder.sol";
import "./Constants.sol";
import "v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";
import "./lib/SenderSlot.sol";

// TODO : create interface, events, and move errors
// TODO : use id instead of tokens address
// TODO : make documentation on how to properly initialize the pool
// TOD : refactor and move some to state.sol
contract CorkHook is BaseHook, Ownable {
    using Clones for address;
    using PoolStateLibrary for PoolState;
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    uint256 public constant AMOUNT_IN_EXTRA_WORKAROUND = 11000;

    error DisableNativeLiquidityModification();

    error AlreadyInitialized();

    error NotInitialized();

    /// @notice Pool state
    mapping(AmmId => PoolState) internal pool;

    // we will deploy proxy to this address for each pool
    address lpBase;
    HookForwarder forwarder;

    constructor(IPoolManager _poolManager, LiquidityToken _lpBase) BaseHook(_poolManager) Ownable(msg.sender) {
        lpBase = address(_lpBase);
        forwarder = new HookForwarder(_poolManager);
    }

    modifier onlyInitialized(address a, address b) {
        AmmId ammId = toAmmId(a, b);
        PoolState storage self = pool[ammId];

        if (!self.isInitialized()) {
            revert NotInitialized();
        }
        _;
    }

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true, // deploy lp tokens for this pool
            afterInitialize: false,
            beforeAddLiquidity: true, // override, only allow adding liquidity from the hook
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, // override, only allow removing liquidity from the hook
            afterRemoveLiquidity: false,
            beforeSwap: true, // override, use our price curve
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true, // override, use our price curve
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        revert DisableNativeLiquidityModification();
    }

    function beforeInitialize(address, PoolKey calldata key, uint160) external virtual override returns (bytes4) {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        AmmId ammId = toAmmId(token0, token1);

        if (pool[ammId].isInitialized()) {
            revert AlreadyInitialized();
        }

        LiquidityToken lp = LiquidityToken(lpBase.clone());
        pool[ammId].initialize(token0, token1, address(lp));

        // the reason we just concatenate the addresses instead of their respective symbols is that because this way, we don't need to worry about
        // tokens symbols to have different encoding and other shinanigans. Frontend should parse and display the token symbols accordingly
        string memory identifier =
            string.concat(Strings.toHexString(uint160(token0)), "-", Strings.toHexString(uint160(token1)));

        lp.initialize(string.concat("Liquidity Token ", identifier), string.concat("LP-", identifier), address(this));

        return this.beforeInitialize.selector;
    }

    function _ensureValidAmount(uint256 amount0, uint256 amount1) internal pure {
        if (amount0 == 0 && amount1 == 0) {
            revert("Invalid Amount");
        }

        if (amount0 != 0 && amount1 != 0) {
            revert("Invalid Amount");
        }
    }

    // we default to exaact out swap, since it's easier to do flash swap this way
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        onlyInitialized(ra, ct)
        returns (uint256 amountIn)
    {
        SortResult memory sortResult = sortPacked(ra, ct, amountRaOut, amountCtOut);
        _ensureValidAmount(sortResult.amount0, sortResult.amount1);

        // if the amount1 is zero, then we swap token0 to token1, and vice versa
        bool zeroForOne = sortResult.amount0 <= 0;
        uint256 out = zeroForOne ? sortResult.amount1 : sortResult.amount0;

        {
            PoolState storage self = pool[toAmmId(sortResult.token0, sortResult.token1)];
            amountIn = _getAmountIn(self, zeroForOne, out);
        }
        // all sanitiy check should go here

        bytes memory swapData;
        IPoolManager.SwapParams memory ammSwapParams;
        ammSwapParams = IPoolManager.SwapParams(zeroForOne, int256(out), Constants.SQRT_PRICE_1_1);

        SwapParams memory params;
        PoolKey memory key = getPoolKey(sortResult.token0, sortResult.token1);

        params = SwapParams(data, ammSwapParams, key, msg.sender, out, amountIn);
        swapData = abi.encode(Action.Swap, params);

        poolManager.unlock(swapData);
    }

    function _initSwap(SwapParams memory params) internal {
        // trf user token to forwarder
        address token0 = Currency.unwrap(params.poolKey.currency0);
        address token1 = Currency.unwrap(params.poolKey.currency1);

        if (params.params.zeroForOne) {
            IERC20(token0).transferFrom(params.sender, address(forwarder), params.amountIn + AMOUNT_IN_EXTRA_WORKAROUND);
        } else {
            IERC20(token1).transferFrom(params.sender, address(forwarder), params.amountIn + AMOUNT_IN_EXTRA_WORKAROUND);
        }

        forwarder.swap(params);
    }

    function _addLiquidity(PoolState storage self, uint256 amount0, uint256 amount1, address sender) internal {
        self.addLiquidity(amount0, amount1, sender);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // settle claims token
        token0.settle(poolManager, sender, amount0, false);
        token1.settle(poolManager, sender, amount1, false);

        // take the tokens
        token0.take(poolManager, address(this), amount0, true);
        token1.take(poolManager, address(this), amount1, true);
    }

    function _removeLiquidity(PoolState storage self, uint256 liquidityAmount, address sender) internal {
        (uint256 amount0, uint256 amount1,,) = self.removeLiquidity(liquidityAmount, sender);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // burn claims token
        token0.settle(poolManager, address(this), amount0, true);
        token1.settle(poolManager, address(this), amount1, true);

        // send back the tokens
        token0.take(poolManager, sender, amount0, false);
        token1.take(poolManager, sender, amount1, false);
    }

    function updateBaseFeePercentage(address ra, address ct, uint256 baseFeePercentage)
        external
        onlyOwner
        onlyInitialized(ra, ct)
    {
        pool[toAmmId(ra, ct)].fee = baseFeePercentage;
    }

    function addLiquidity(address ra, address ct, uint256 raAmount, uint256 ctAmount)
        external
        returns (uint256 mintedLp)
    {
        (address token0, address token1, uint256 amount0, uint256 amount1) = sort(ra, ct, raAmount, ctAmount);

        // all sanitiy check should go here
        // TODO : auto-initialize pool if not initialized
        if (!pool[toAmmId(token0, token1)].isInitialized()) {
            forwarder.initializePool(token0, token1);
        }

        // retruns how much liquidity token was minted
        (,, mintedLp) = pool[toAmmId(token0, token1)].tryAddLiquidity(amount0, amount1);

        AddLiquidtyParams memory params = AddLiquidtyParams(token0, amount0, token1, amount1, msg.sender);

        bytes memory data = abi.encode(Action.AddLiquidity, params);

        poolManager.unlock(data);
    }

    function removeLiquidity(address ra, address ct, uint256 liquidityAmount)
        external
        onlyInitialized(ra, ct)
        returns (uint256 amountRa, uint256 amountCt)
    {
        (address token0, address token1) = sort(ra, ct);

        // all sanitiy check should go here
        // TODO : maybe add more sanity checks

        // check if pool is initialized
        AmmId ammId = toAmmId(token0, token1);
        PoolState storage self = pool[ammId];

        if (!self.isInitialized()) {
            revert NotInitialized();
        }

        (uint256 amount0, uint256 amount1,,) = pool[toAmmId(token0, token1)].tryRemoveLiquidity(liquidityAmount);
        (,, amountRa, amountCt) = reverseSortWithAmount(ra, ct, token0, token1, amount0, amount1);

        RemoveLiquidtyParams memory params = RemoveLiquidtyParams(token0, token1, liquidityAmount, msg.sender);

        bytes memory data = abi.encode(Action.RemoveLiquidity, params);

        poolManager.unlock(data);
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        Action action = abi.decode(data, (Action));

        if (action == Action.AddLiquidity) {
            (, AddLiquidtyParams memory params) = abi.decode(data, (Action, AddLiquidtyParams));

            _addLiquidity(pool[toAmmId(params.token0, params.token1)], params.amount0, params.amount1, params.sender);
            // TODO : right now the selector return is unused
            return "";
        }

        if (action == Action.RemoveLiquidity) {
            (, RemoveLiquidtyParams memory params) = abi.decode(data, (Action, RemoveLiquidtyParams));

            _removeLiquidity(pool[toAmmId(params.token0, params.token1)], params.liquidityAmount, params.sender);
            // TODO : right now the selector return is unused
            return "";
        }

        if (action == Action.Swap) {
            (, SwapParams memory params) = abi.decode(data, (Action, SwapParams));

            _initSwap(params);
        }

        return "";
    }

    function getLiquidityToken(address ra, address ct) external view onlyInitialized(ra, ct) returns (address) {
        return address(pool[toAmmId(ra, ct)].liquidityToken);
    }

    function getReserves(address ra, address ct) external view onlyInitialized(ra, ct) returns (uint256, uint256) {
        return (pool[toAmmId(ra, ct)].reserve0, pool[toAmmId(ra, ct)].reserve1);
    }

    // IMPORTANT: ALL SWAP MUST GIVE 11000 WEI EXTRA TO AVOID K DECREASED
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta delta, uint24) {
        PoolState storage self = pool[toAmmId(Currency.unwrap(key.currency0), Currency.unwrap(key.currency1))];
        // kinda packed, avoid stack too deep

        delta = toBeforeSwapDelta(
            -int128(params.amountSpecified), int128(int256(_beforeSwap(self, params, hookData, sender)))
        );

        // TODO: do we really need to specify the fee here?
        return (this.beforeSwap.selector, delta, 0);
    }

    function _beforeSwap(
        PoolState storage self,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData,
        address sender
    ) internal returns (uint256 unspecificiedAmount) {
        bool exactIn = (params.amountSpecified < 0);
        uint256 amountIn;
        uint256 amountOut;

        // we calculate how much they must pay
        if (exactIn) {
            amountIn = uint256(-params.amountSpecified);
            amountOut = _getAmountOut(self, params.zeroForOne, amountIn);
        } else {
            amountOut = uint256(params.amountSpecified);
            amountIn = _getAmountIn(self, params.zeroForOne, amountOut);
            (params.zeroForOne, amountOut);
        }

        unspecificiedAmount = exactIn ? amountOut : amountIn;

        (Currency input, Currency output) = _getInputOutput(self, params.zeroForOne);

        (uint256 kBefore,) = _k(self);

        self.ensureLiquidityEnough(amountOut, Currency.unwrap(output));

        // update reserve
        self.updateReserves(Currency.unwrap(output), amountOut, true);

        // we transfer their tokens, i.e we settle the output token first so that the user can take the input token
        output.settle(poolManager, address(this), amountOut, true);

        // there is data, means flash swap
        if (hookData.length > 0) {
            // avoid stack too deep
            forwarder.forwardToken(input, output, amountIn, amountOut);
            // will 0 if user pay with the same token
            unspecificiedAmount = _executeFlashSwap(self, hookData, input, output, amountIn, amountOut, sender, exactIn);
            // no data, means normal swap
        } else {
            // update reserve
            self.updateReserves(Currency.unwrap(input), amountIn, false);

            // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user
            input.take(poolManager, sender, amountIn, false);

            // forward token to user if caller is forwarder
            forwarder.forwardToken(input, output, amountIn, amountOut);
        }

        (uint256 kAfter,) = _kWithFee(self, amountIn, input);

        // ensure k isn't less than before
        require(kAfter >= kBefore, "K_DECREASED");
    }

    function _kWithFee(PoolState storage self, uint256 amountIn, Currency input)
        internal
        view
        returns (uint256 k, uint256 fee)
    {
        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);
        fee = SwapMath.getFee(amountIn, self.fee, start, end, block.timestamp);

        (uint256 reserve0, uint256 reserve1) = (self.reserve0, self.reserve1);

        // subtract from reserve if input is token0
        reserve0 = Currency.unwrap(input) == self.token0 ? reserve0 - fee : reserve0;
        // subtract from reserve if input is token1
        reserve1 = Currency.unwrap(input) == self.token1 ? reserve1 - fee : reserve1;

        k = SwapMath.getInvariant(reserve0, reserve1, start, end, block.timestamp);
    }

    function getFee(address ra, address ct)
        external
        view
        onlyInitialized(ra, ct)
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage)
    {
        baseFeePercentage = pool[toAmmId(ra, ct)].fee;

        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(pool[toAmmId(ra, ct)]);
        actualFeePercentage = SwapMath.getFeePercentage(baseFeePercentage, start, end, block.timestamp);
    }

    function _executeFlashSwap(
        PoolState storage self,
        bytes calldata hookData,
        Currency input,
        Currency output,
        uint256 amountIn,
        uint256 amountOut,
        address sender,
        bool exactIn
    ) internal returns (uint256 unspecificiedAmount) {
        // infer what token would be used for payment, if counterPayment is true, then the input token is used for payment, otherwise its the output token
        bool counterPayment = abi.decode(hookData, (bool));

        {
            // we expect user to use exact output swap when dealing with flash swap
            // so we use amountOut as the payment amount cause they simply have to return the borrowed amount
            // or it's the in amount that they have to pay with the other token
            (uint256 paymentAmount, address paymentToken) =
                counterPayment ? (amountIn, Currency.unwrap(input)) : (amountOut, Currency.unwrap(output));

            // call the callback
            CorkSwapCallback(sender).CorkCall(sender, hookData, paymentAmount, paymentToken, address(poolManager));
        }

        // process repayments
        if (counterPayment) {
            // update reserve
            self.updateReserves(Currency.unwrap(input), amountIn, false);

            // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user, at this point, the user should've created a debit on the PM
            input.take(poolManager, sender, amountIn, false);

            // this is similar to normal swap, the unspecified amount is the other tokens
            unspecificiedAmount = exactIn ? amountOut : amountIn;
        } else {
            // update reserve
            self.updateReserves(Currency.unwrap(output), amountOut, false);

            // we take the original borrowed tokens from the pool manager, at this point the hook should still have the original debit outstanding on the PM
            output.take(poolManager, sender, amountOut, false);

            // no swap actually occured, the user has paid their balance
            unspecificiedAmount = 0;
        }
    }

    function _getAmountIn(PoolState storage self, bool zeroForOne, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        (uint256 invariant, uint256 oneMinusT) = _k(self);
        // TODO : workaround for now, if not for this then the k will decrease slightly than we expected(only work for 1000 :1050 reserve with 1 swao amount at time of 1-t = 0.1)
        amountIn = SwapMath.getAmountIn(amountOut, reserveIn, reserveOut, invariant, oneMinusT, self.fee)
            + AMOUNT_IN_EXTRA_WORKAROUND;
    }

    function _getAmountOut(PoolState storage self, bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        (uint256 invariant, uint256 oneMinusT) = _k(self);
        amountOut = SwapMath.getAmountOut(amountIn, reserveIn, reserveOut, invariant, oneMinusT, self.fee);
    }

    function _getInputOutput(PoolState storage self, bool zeroForOne)
        internal
        view
        returns (Currency input, Currency output)
    {
        (address _input, address _output) = zeroForOne ? (self.token0, self.token1) : (self.token1, self.token0);
        return (Currency.wrap(_input), Currency.wrap(_output));
    }

    function _getIssuedAndMaturationTime(PoolState storage self) internal view returns (uint256 start, uint256 end) {
        IExpiry token0 = IExpiry(self.token0);
        IExpiry token1 = IExpiry(self.token1);

        try token0.issuedAt() returns (uint256 issuedAt0) {
            start = issuedAt0;
            end = token0.expiry();
            return (start, end);
        } catch {}

        try token1.issuedAt() returns (uint256 issuedAt1) {
            start = issuedAt1;
            end = token1.expiry();
            return (start, end);
        } catch {}

        revert("Invalid Token Pairs, no expiry found");
    }

    function _k(PoolState storage self) internal view returns (uint256 invariant, uint256 oneMinusT) {
        (uint256 reserve0, uint256 reserve1) = (self.reserve0, self.reserve1);
        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);

        invariant = SwapMath.getInvariant(reserve0, reserve1, start, end, block.timestamp);
        oneMinusT = SwapMath.oneMinusT(start, end, block.timestamp);
    }

    function getPoolKey(address ra, address ct) public view returns (PoolKey memory) {
        (address token0, address token1) = sort(ra, ct);
        return PoolKey(
            Currency.wrap(token0), Currency.wrap(token1), Constants.FEE, Constants.TICK_SPACING, IHooks(address(this))
        );
    }
}
