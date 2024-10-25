# Deploying Locally(anvil)

start anvil on 1 terminal

```bash
anvil
```

deploy locally on another terminal

```bash
forge script ./script/DeployLocal.s.sol --broadcast --tc DeployLocalScript --rpc-url localhost:8545 -vv
```
