## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Social Recovery Anomaly Trap

This project implements a `SocialRecoveryAnomalyTrap` and a `ResponseContract` designed to work within the Drosera network. The trap monitors a social recovery wallet for significant, rapid changes to its guardian set, triggering a predefined response if an anomaly is detected.

### Key Features and Improvements:

- **ITrap Interface Compliance**: The `SocialRecoveryAnomalyTrap` now fully implements the `ITrap` interface, including `collect()` and `shouldRespond()` functions with correct `view`/`pure` modifiers.
- **Order-Independent Guardian Comparison**: The `shouldRespond` function now sorts guardian lists before comparison, ensuring that changes in guardian order alone do not trigger false positives.
- **Rising-Edge Guard**: A rising-edge check has been implemented to prevent the trap from re-triggering repeatedly while a large change persists across multiple blocks.
- **ResponseContract Access Control**: The `ResponseContract` now includes an immutable `allowed` address, ensuring that only authorized entities (e.g., a Drosera executor) can call `triggerTimelock`.

### Mock Wallet Caveats:

For testing and proof-of-concept purposes, the `MockSocialRecoveryWallet` allows anyone to change guardians and activate the timelock. In a production environment, these functions would be protected by appropriate access controls.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```