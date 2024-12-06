## Makina Core Smart Contracts

This repository contains the core smart contracts of Makina.

## Contracts Overview

| Filename | Deployment chain | Description |
| --- | --- | --- |
| `HubRegistry.sol` | Hub | Stores hub chain factories, oracle registry, swapper module and beacons for machines, calibers and inboxes. |
| `SpokeRegistry.sol` | Spoke | Stores spoke chain factories, oracle registry, swapper module, and beacons for calibers and inboxes. |
| `OracleRegistry.sol` | Hub + Spoke | Aggregates price feeds in order to price base tokens against accounting tokens used in machines and calibers. |
| `MachineFactory.sol` | Hub | Factory for creation of machines.
| `Machine.sol` | Hub | Core component of Makina which handles deposits, redemptions and share price calculation. |
| `HubMachineInbox.sol` | Hub | Handles machine communication with a hub caliber. |
| `SpokeMachineInbox.sol` | Hub | Handles machine communication with a spoke caliber. |
| `CaliberFactory.sol` | Hub + Spoke | Factory for creation of machines. |
| `Caliber.sol` | Hub + Spoke | Execution engine used to manage positions. Each machine is attributed a caliber on the hub chain, and can later be attributed one caliber per supported evm chain. |
| `HubCaliberInbox.sol` | Hub | Handles hub caliber communication with hub machine. |
| `SpokeCaliberInbox.sol` | Spoke | Handles spoke caliber communication with hub machine. |
| `Swapper.sol` | Hub + Spoke | Standalone module used by machine and calibers to execute DEX aggregators transactions. |

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

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ yarn format
```

### Anvil

```shell
$ anvil
```
