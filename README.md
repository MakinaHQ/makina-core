# Makina Core Smart Contracts

This repository contains the core smart contracts of the Makina Protocol.

## Background

Makina is a protocol for executing advanced cross-chain investment strategies. It provides the infrastructure for operators to issue tokenized strategies with full DeFi composability and strong risk controls. At the core of each strategy is a Machine contract, on the Hub Chain, which handles deposits, withdrawals, share pricing, and cross-chain coordination. Execution across chains is performed by Calibers, which serve as the strategy’s execution engines across the Hub and and all supported Spoke Chains. Every strategy is defined by a Mandate that outlines its objectives, risk profile, and operating parameters, serving as a reference for the operator, risk managers, the Security Council, and the DAO.

See `SPECIFICATION.md` and `PERMISSIONS.MD` for more details.

## Contracts Overview

| Filename                    | Deployment chain | Description                                                                                                                                         |
| --------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HubCoreRegistry.sol`       | Hub              | Stores addresses of core hub components of the protocol, including registries, factory, and beacons.                                                |
| `SpokeCoreRegistry.sol`     | Spoke            | Stores addresses of core spoke components of the protocol, including registries, factory, and beacons.                                              |
| `OracleRegistry.sol`        | Hub + Spoke      | Aggregates price feeds in order to price base tokens against accounting tokens used in machines and calibers.                                       |
| `TokenRegistry.sol`         | Hub + Spoke      | Maps token addresses across different chains.                                                                                                       |
| `ChainRegistry.sol`         | Hub              | Maps EVM chain IDs to Wormhole chain IDs.                                                                                                           |
| `HubCoreFactory.sol`        | Hub              | Hub factory for creation of machines, machine shares, caliber, bridge adapters, and pre-deposit vaults.                                             |
| `SpokeCoreFactory.sol`      | Spoke            | Spoke factory for creation of calibers, caliber mailboxes and bridge adapters.                                                                      |
| `Machine.sol`               | Hub              | Core component of Makina which handles deposits, redemptions and share price calculation.                                                           |
| `Caliber.sol`               | Hub + Spoke      | Execution engine used to manage positions on each supported chain.                                                                                  |
| `CaliberMailbox.sol`        | Spoke            | Handles communication between a spoke caliber and the hub machine.                                                                                  |
| `SwapModule.sol`            | Hub + Spoke      | Standalone module used by calibers to execute swap transactions through external protocols.                                                         |
| `AcrossV3BridgeAdapter.sol` | Hub + Spoke      | Handles bidirectional bridge transfers via Across V3, between a hub machine and a spoke caliber. Operates with a counterpart on the opposite chain. |

## Installation

Follow [this link](https://book.getfoundry.sh/getting-started/installation) to install the Foundry toolchain.

## Submodules

Run below command to include/update all git submodules like forge-std, openzeppelin contracts etc (`lib/`)

```shell
git submodule update --init --recursive
```

## Dependencies

Run below command to include project dependencies like prettier and solhint (`node_modules/`)

```shell
yarn
```

### Build

Run below command to compile contracts that require IR-based codegen (`src-ir/` and `test-ir/`)

```shell
yarn build:ir
```

Run below command to compile all other contracts

```shell
forge build
```

### Test

Some tests involve network forking. To run them, the `MAINNET_RPC_URL` and `BASE_RPC_URL` variables must be set in a .env file located at the project root.

Some tests also execute JavaScript scripts for Merkle root generation. These require Node.js v18 or later.

```shell
forge test
```

### Coverage

```shell
yarn coverage
```

### Format

```shell
forge fmt
```

### Lint

```shell
yarn lint
```

### Deployment

See `script/README.md` for instructions.
