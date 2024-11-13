const {
  createPublicClient,
  createWalletClient,
  createTestClient,
  http,
  getContract,
  erc20Abi,
  parseEther,
  formatEther,
  parseEventLogs,
  publicActions,
  walletActions,
  encodeAbiParameters,
  parseAbiParameter,
  getAddress,
  isAddress,
  parseAbi,
  decodeAbiParameters,
  decodeErrorResult,
} = require("viem");
const { sepolia, foundry } = require("viem/chains");
const { privateKeyToAccount } = require("viem/accounts");
const { abi: CorkAbi } = require("../out/CorkHook.sol/CorkHook.json");

require("dotenv").config();

const testClient = createTestClient({
  chain: foundry,
  mode: "anvil",
  transport: http(`http://localhost:8545/`),

});

const anvilAccount1 = privateKeyToAccount(`0x${process.env.ANVIL_ACCOUNT_1}`);

async function main() {
  console.log("starting script swap.js...");
  const TOKEN_0 = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
  const TOKEN_1 = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
  const CORK_HOOK = "0x0E14326e2e15bDD03aD9b27e12AeCF8E79BD6a88";
  const POOL_MANAGER = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  const FETCHER = "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e";

  const symbol = await testClient.extend(publicActions).readContract({
    address: TOKEN_0,
    abi: erc20Abi,
    functionName: "symbol",
  });
  console.log("check symbol", symbol);

  const blockNumber = await testClient.extend(publicActions).getBlockNumber();
  console.log("check blockNumber", blockNumber);

  const balanceOfToken0 = await testClient.extend(publicActions).readContract({
    address: TOKEN_0,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [anvilAccount1.address],
  });
  console.log("test calling balance of Token0", formatEther(balanceOfToken0));

  const getPoolManager = await testClient.extend(publicActions).readContract({
    address: CORK_HOOK,
    abi: CorkAbi,
    functionName: "getPoolManager",
  });

  console.log("getPoolManager", getPoolManager);

  const getPoolKey = await testClient.extend(publicActions).readContract({
    address: CORK_HOOK,
    abi: CorkAbi,
    functionName: "getPoolKey",
    args: [TOKEN_0, TOKEN_1],
  });

  console.log("getPoolKey", getPoolKey);

  const getForwarder = await testClient.extend(publicActions).readContract({
    address: CORK_HOOK,
    abi: CorkAbi,
    functionName: "getForwarder",
  });

  console.log("getForwarder", getForwarder);

  // //   get liqiudity token: error starts here
  if (
    !isAddress(TOKEN_0) || !isAddress(TOKEN_1)
  ) {
    throw new Error("Invalid address");
  }

  // console.log(decodeErrorResult({
  //   abi: parseAbi([
  //     "error PoolNotInitialized()",
  //     "error CurrenciesOutOfOrderOrEqual(address currency0, address currency1)",
  //     "error ManagerLocked()",
  //     "error InvalidCaller()",
  //     "error ProtocolFeeCannotBeFetched()",
  //     "error ProtocolFeeTooLarge(uint24 fee)",
  //     "error ContractUnlocked()",
  //     "error SwapAmountCannotBeZero()",
  //     "error NonzeroNativeValue()",
  //     "error MustClearExactPositiveDelta()",
  //     "error TickSpacingTooLarge(int24 tickSpacing)",
  //     "error TickSpacingTooSmall(int24 tickSpacing)",
  //     "error CurrenciesOutOfOrderOrEqual(address currency0, address currency1)",
  //     "error Wrap__NativeTransferFailed(address recipient, bytes reason)",
  //     "error Wrap__ERC20TransferFailed(address token, bytes reason)",
  //     "error SafeCastOverflow()",
  //     "error Expired()",
  //   ]).join(CorkAbi),
  //   data: "0xec442f05"
  // }));


  // get fee error
  // const getFee = await testClient.extend(publicActions).readContract({
  //   address: CORK_HOOK,
  //   abi: CorkAbi,
  //   functionName: "getFee",
  //   args: [TOKEN_0, TOKEN_1],
  // });

  // console.log("getFee", getFee);

  // APPROVE
  const { request: approveToken0 } = await testClient
    .extend(publicActions)
    .extend(walletActions)
    .writeContract({
      account: anvilAccount1.address,
      address: TOKEN_0,
      abi: erc20Abi,
      functionName: "approve",
      args: [CORK_HOOK, parseEther("10000")],
    });

  console.log("approveToken0", approveToken0);

  // const testWrite = testClient.extend(walletActions);

  // const hashApproval = await testWrite.writeContract(approveToken0);

  // console.log("hashApproval", hashApproval);

  // ADD LIQUIDITY
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

  const addLiquidity = await testClient.extend(walletActions).writeContract({
    account: anvilAccount1.address,
    address: CORK_HOOK,
    abi: CorkAbi,
    functionName: "addLiquidity",
    args: [
      TOKEN_0,
      TOKEN_1,
      parseEther("1"),
      parseEther("1"),
      parseEther("0"),
      parseEther("0"),
      deadline,
    ],
  });

  console.log("addLiquidity", addLiquidity);


  let getLiquidityToken = await testClient
    .extend(publicActions)
    .readContract({
      address: CORK_HOOK,
      abi: CorkAbi,
      functionName: "getLiquidityToken",
      args: [TOKEN_0, TOKEN_1]
    })
  console.log("getLiquidityToken", getLiquidityToken);


  // const getAmountOut = await testClient.extend(publicActions).readContract({
  //   address: CORK_HOOK,
  //   abi: CorkAbi,
  //   functionName: "getAmountOut",
  //   args: [TOKEN_0, TOKEN_1, bool raForCt, uint256 amountOut],
  // });

  // console.log("getFee", getFee);

  // const swap = await testClient.extend(publicActions).readContract({
  //   address: CORK_HOOK,
  //   abi: CorkAbi,
  //   functionName: "swap",
  //   args: [(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data],
  // });

  // console.log("swap", swap);

  // approve CorkHook
  // const { request: approveToken0 } = await testClient
  //   .extend(publicActions)
  //   .simulateContract({
  //     account: anvilAccount1.address,
  //     address: TOKEN_0,
  //     abi: erc20Abi,
  //     functionName: "approve",
  //     args: [CORK_HOOK, parseEther("10000")],
  //   });

  // console.log("approveToken0", approveToken0);

  // const testWrite = testClient.extend(walletActions);

  // const hashApproval = await testWrite.writeContract(approveToken0);

  // console.log("hash approval", hashApproval);

  // getAmountIn
  // const getAmountIn = await testClient.extend(publicActions).readContract({
  //   account: anvilAccount1.address,
  //   address: CORK_HOOK,
  //   abi: CorkAbi,
  //   functionName: "getAmountIn",
  //   args: [TOKEN_0, TOKEN_1, true, parseEther("1")],
  // });

  // const amountIn = await getAmountIn();
  // console.log("amountIn", amountIn);
}

main().catch((error) => {
  console.log("error", error);
  process.exitCode = 1;
});
