pragma solidity ^0.8.0;

import "forge-std/mocks/MockERC20.sol";
import {CorkHook, LiquidityToken, AmmId, PoolState} from "./../src/CorkHook.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Asset} from "Depeg-swap/contracts/core/assets/Asset.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

import "forge-std/Script.sol";
import "./HookMiner.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "Depeg-swap/contracts/interfaces/IExpiry.sol";

contract DeployLocalScript is Script, StdCheats {
    /// @notice account 0 private key on anvil
    uint256 internal constant pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal user = vm.addr(pk);
    address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint256 expiry = block.timestamp + 10 days;
    // irrelevant
    uint256 rate = 1000;

    PoolManager poolManager;

    Asset token0;
    Asset token1;

    LiquidityToken lpBase;
    CorkHook hook;

    uint160 flags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function run() public {
        vm.startBroadcast(pk);

        poolManager = new PoolManager();
        token0 = new Asset("TK", "0", user, expiry, rate);
        token1 = new Asset("TK", "1", user, expiry, rate);

        token0.mint(user, type(uint256).max);
        token1.mint(user, type(uint256).max);

        //sort
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        lpBase = new LiquidityToken();

        bytes memory creationCode = type(CorkHook).creationCode;
        bytes memory args = abi.encode(poolManager, lpBase);

        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, flags, creationCode, args);

        hook = new CorkHook{salt: salt}(poolManager, lpBase);
        require(address(hook) == hookAddress, "Hook address mismatch");

        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 0, 1, IHooks(hook));
        poolManager.initialize(key, SQRT_PRICE_1_1);

        vm.stopBroadcast();

        console.log("-------------------- Address --------------------");
        console.log("PoolManager    :", address(poolManager));
        console.log("Token0         :", address(token0));
        console.log("Token1         :", address(token1));
        console.log("CorkHook       :", address(hook));
    }
}

// for some reason, it fails to compile of we import directly from helper. so we put it here as a workaround
contract DummyErc20 is MockERC20, IExpiry {
    uint256 _issuedAt;
    uint256 _expiry;

    constructor() {
        _issuedAt = block.timestamp;
        _expiry = block.timestamp + 10 days;
    }

    function expiry() external view override returns (uint256) {
        return _expiry;
    }

    function issuedAt() external view override returns (uint256) {
        return _issuedAt;
    }

    function isExpired() external view override returns (bool) {
        return block.timestamp >= _expiry;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}
