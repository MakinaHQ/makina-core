## Makina Core Smart Contracts

This repository contains the core smart contracts of Makina.

## Contracts Overview

| Filename                     | Deployment chain | Description                                                                                                                                                        |
| ---------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `HubRegistry.sol`            | Hub              | Stores hub chain factories, oracle registry, swapModule module and beacons for machines, calibers and mailboxes.                                                   |
| `SpokeRegistry.sol`          | Spoke            | Stores spoke chain factories, oracle registry, swapModule module, and beacons for calibers and mailboxes.                                                          |
| `OracleRegistry.sol`         | Hub + Spoke      | Aggregates price feeds in order to price base tokens against accounting tokens used in machines and calibers.                                                      |
| `TokenRegistry.sol`          | Hub + Spoke      | Maps token addresses accross different chains.                                                                                                                     |
| `ChainRegistry.sol`          | Hub              | Maps EVM chain IDs to Wormhole chain IDs.                                                                                                                          |
| `MachineFactory.sol`         | Hub              | Hub chain factory for creation of machines, machine shares, caliber and bridge adapters.                                                                           |
| `Machine.sol`                | Hub              | Core component of Makina which handles deposits, redemptions and share price calculation.                                                                          |
| `CaliberFactory.sol`         | Spoke            | Spoke chain factory for creation of calibers caliber mailboxes and bridge adapters.                                                                                |
| `Caliber.sol`                | Hub + Spoke      | Execution engine used to manage positions. Each machine is attributed a caliber on the hub chain, and can later be attributed one caliber per supported evm chain. |
| `CaliberMailbox.sol`         | Spoke            | Handles spoke caliber communication with hub machine.                                                                                                              |
| `SwapModule.sol`             | Hub + Spoke      | Standalone module used by calibers to execute swap transactions through external protocols.                                                                        |
| `AccrossV3BridgeAdapter.sol` | Hub + Spoke      | Handles bidirectional bridge transfers via Accross V3, between a hub machine and a spoke caliber. Operates with a counterpart on the opposite chain.               |

## Installation

Follow [this link](https://book.getfoundry.sh/getting-started/installation) to install foundry, forge, cast and anvil

Do not forget to update foundry regularly with the following command

```properties
foundryup
```

Similarly for forge-std run

```properties
forge update lib/forge-std
```

## Submodules

Run below command to include/update all git submodules like openzeppelin contracts, forge-std etc (`lib/`)

```properties
git submodule update --init --recursive
```

## Dependencies

Run below command to include project dependencies like prettier and solhint (`node_modules/`)

```properties
yarn
```

### Build

Run below command to compile contracts that require IR-based codegen (`src-ir/` and `test-ir/`)
```shell
$ yarn build:ir
```

Run below command to compile all other contracts
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

### Anvil

```shell
$ anvil
```
