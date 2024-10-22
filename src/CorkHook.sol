pragma solidity ^0.8.19;

// TODO : refactor named imports
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import "v4-periphery/lib/v4-core/src/types/PoolId.sol";
import "v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import "v4-periphery/lib/v4-core/src/types/Currency.sol";
import "v4-periphery/src/base/hooks/BaseHook.sol";
import "./LiquidityToken.sol";
import "./lib/State.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import "./lib/Calls.sol";
import "forge-std/console.sol";

// TODO : create interface, events, and move errors
// TODO : use id instead of tokens address
contract CorkHook is BaseHook {
    using Clones for address;
    using PoolStateLibrary for PoolState;
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    error DisableNativeLiquidityModification();

    error AlreadyInitialized();

    error NotInitialized();

    /// @notice Pool state
    mapping(AmmId => PoolState) internal pool;

    // we will deploy proxy to this address for each pool
    address lpBase;

    constructor(IPoolManager _poolManager, LiquidityToken _lpBase) BaseHook(_poolManager) {
        lpBase = address(_lpBase);
    }

    modifier onlyInitialized(address a, address b) {
        AmmId ammId = toAmmId(a, b);
        PoolState storage self = pool[ammId];

        if (!self.isInitialized()) {
            revert NotInitialized();
        }
        _;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        virtual
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // we calculate how much they must pay
        // we transfer their tokens
        // we call their callback if they specify(they should approve us to spend their tokens equals to how much they must pay)
        // we transfer user tokens to the pool equal to how much they must pay
        return this.beforeSwap.selector;
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
            beforeSwapReturnDelta: false,
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

    function addLiquidity(address ra, address ct, uint256 raAmount, uint256 ctAmount)
        external
        onlyInitialized(ra, ct)
        returns (uint256 mintedLp)
    {
        (address token0, address token1, uint256 amount0, uint256 amount1) = sort(ra, ct, raAmount, ctAmount);

        // all sanitiy check should go here
        // TODO : maybe add more sanity checks

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
            // TODO : find out what the return value should be used for
            return "";
        }

        if (action == Action.RemoveLiquidity) {
            (, RemoveLiquidtyParams memory params) = abi.decode(data, (Action, RemoveLiquidtyParams));

            _removeLiquidity(pool[toAmmId(params.token0, params.token1)], params.liquidityAmount, params.sender);
            // TODO : find out what the return value should be used for
            return "";
        }

        return "";
    }

    function getLiquidityToken(address ra, address ct) external view onlyInitialized(ra, ct) returns (address) {
        return address(pool[toAmmId(ra, ct)].liquidityToken);
    }

    function getReserves(address ra, address ct) external view onlyInitialized(ra, ct) returns (uint256, uint256) {
        return (pool[toAmmId(ra, ct)].reserve0, pool[toAmmId(ra, ct)].reserve1);
    }
}
