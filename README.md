## Makina Core Smart Contracts

This repository contains the core smart contracts of Makina.

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
