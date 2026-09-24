# Deploy Makina Core

This README outlines the steps to deploy the Makina Core contracts.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs and the Etherscan API key.
- Build the project as described in the [root README](../README.md). `yarn build:ir` is required, as the scripts deploy `WeirollVM` from the IR build output.
- Some networks are preconfigured in `foundry.toml` and only require the corresponding environment variables. More networks can be added following similar configuration.
- Notation used in the commands:
  - `<wallet-options>` - the flags specifying the deployer wallet, e.g. `--account <keystore-name>` for a Foundry keystore. For other options, refer to the [Foundry docs](https://getfoundry.sh/forge/reference/script/)
  - `<network-alias>` - must match a network name declared in `foundry.toml`
- Each script documents its env vars in its NatSpec header.

## Hub Chain Deployments

Set the `HUB_CORE_INPUT_FILENAME` and `HUB_CORE_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

### Shared contracts

1. Copy `script/deployments/inputs/hub-cores/TEMPLATE.json` to `script/deployments/inputs/hub-cores/{HUB_CORE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-cores/{HUB_CORE_OUTPUT_FILENAME}` containing the deployed contract addresses.

```shell
forge script script/deployments/DeployHubCore.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

Note: This script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx). Implementation contracts already deployed by the same wallet are reused, and the script fails before broadcasting when a deterministic address is already occupied.

A deployment is either staging, where the deployer keeps sole control of the `AccessManager`, or production, where control is handed to the accounts configured in the input file.

#### Staging: skip the AccessManager setup

Set `SKIP_AM_SETUP=true` to skip the `AccessManager` setup (function roles and role grants). The deployer keeps the `ADMIN_ROLE` and runs the strategy instance scripts below directly. Leave unset (or `false`) for production.

### Shared contracts of a foreign instance

An instance is one hub core plus the spoke cores reporting to it, identified by its hub chain id. A chain already hosting a core of the main instance can host the core of a second, foreign instance: the chain-scoped contracts (`AccessManager`, `OracleRegistry`, `TokenRegistry`, `WeirollVM` and the bridge configs) are shared, and only the instance-scoped contracts are deployed, at deterministic addresses discriminated by the foreign instance's hub chain id.

The shared contracts are read off the main instance's core registry on this chain, `mainCoreRegistry` in the input file. On the hub chain of a foreign instance, the main instance is a spoke, so that is its `SpokeCoreRegistry`.

Uses the same `HUB_CORE_INPUT_FILENAME` and `HUB_CORE_OUTPUT_FILENAME` variables as above.

1. Copy `script/deployments/inputs/hub-cores/Foreign-TEMPLATE.json` to `script/deployments/inputs/hub-cores/{HUB_CORE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-cores/{HUB_CORE_OUTPUT_FILENAME}` containing the addresses of the contracts deployed by this script only.

```shell
forge script script/deployments/DeployForeignHubCore.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

3. Run the following command to log the calldata wiring the deployed contracts: the registry setters and swapper targets, then the `AccessManager` function roles and the `HubCoreFactory`'s `ADMIN_ROLE` grant. Every call is restricted to the `ADMIN_ROLE` of the shared `AccessManager`, and is logged alongside its `AccessManager.schedule` wrapper for roles with an execution delay, for the role holder to submit in this order.

```shell
VIEW_MODE=true forge script script/deployments/SetupForeignHubCore.s.sol --rpc-url <network-alias> -vvvv
```

Leave `VIEW_MODE` unset to broadcast the calls directly, from a wallet holding the `ADMIN_ROLE` (staging deployments).

Strategy instances are then deployed with the scripts below, unchanged: they read the `HubCoreFactory` address from the output file.

### Strategy instances

In addition to `HUB_CORE_INPUT_FILENAME` and `HUB_CORE_OUTPUT_FILENAME` set above for shared contracts deployments, set the `HUB_STRAT_INPUT_FILENAME` and `HUB_STRAT_OUTPUT_FILENAME` values in your `.env` file.

The factory functions creating strategy instances are restricted to the `STRATEGY_DEPLOYMENT_ROLE`. The scripts below broadcast from the deployer wallet, or run in view mode for production.

#### Production: view mode

In production, strategy instances are created from an account holding the `STRATEGY_DEPLOYMENT_ROLE`. Set `VIEW_MODE=true` to log the call's target (the core factory) and calldata for that account to submit, alongside its `AccessManager.schedule` wrapper for roles with an execution delay, instead of broadcasting. No `<wallet-options>` are needed, and no output file is written (`HUB_STRAT_OUTPUT_FILENAME` can be left unset). The setting applies to all strategy instance scripts. Leave the variable unset (or `false`) to broadcast.

#### Hub Machine instance

1. Copy `script/deployments/inputs/hub-machines/TEMPLATE.json` to `script/deployments/inputs/hub-machines/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-machines/{HUB_STRAT_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeployHubMachine.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

#### Pre-Deposit Vault instance

1. Copy `script/deployments/inputs/pre-deposit-vaults/TEMPLATE.json` to `script/deployments/inputs/pre-deposit-vaults/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/pre-deposit-vaults/{HUB_STRAT_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeployPreDepositVault.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

#### Pre-Deposit Vault instance migration into Hub Machine instance

1. Copy `script/deployments/inputs/pre-deposit-migrations/TEMPLATE.json` to `script/deployments/inputs/pre-deposit-migrations/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/pre-deposit-migrations/{HUB_STRAT_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeployHubMachineFromPreDeposit.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

## Spoke Chain Deployments

Set the `SPOKE_CORE_INPUT_FILENAME` and `SPOKE_CORE_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Base Mainnet, both of these files can be named `Base.json`.

### Shared contracts

1. Copy `script/deployments/inputs/spoke-cores/TEMPLATE.json` to `script/deployments/inputs/spoke-cores/{SPOKE_CORE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/spoke-cores/{SPOKE_CORE_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeploySpokeCore.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

Note: Same as for hub chain shared contracts deployment, this script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx). The `SKIP_AM_SETUP` setting applies as described for the hub chain.

### Shared contracts of a foreign instance

Same as for the hub chain, with the spoke-side scripts and template. The input file names the foreign instance's `hubChainId`, and `mainCoreRegistry` is the main instance's core registry on this chain, hub or spoke depending on its role there. Uses the same `SPOKE_CORE_INPUT_FILENAME` and `SPOKE_CORE_OUTPUT_FILENAME` variables as above.

1. Copy `script/deployments/inputs/spoke-cores/Foreign-TEMPLATE.json` to `script/deployments/inputs/spoke-cores/{SPOKE_CORE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/spoke-cores/{SPOKE_CORE_OUTPUT_FILENAME}` containing the addresses of the contracts deployed by this script only.

```shell
forge script script/deployments/DeployForeignSpokeCore.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

3. Run the following command to log the calldata wiring the deployed contracts, as described for the hub chain.

```shell
VIEW_MODE=true forge script script/deployments/SetupForeignSpokeCore.s.sol --rpc-url <network-alias> -vvvv
```

### Strategy instances

In addition to `SPOKE_CORE_INPUT_FILENAME` and `SPOKE_CORE_OUTPUT_FILENAME` set above for shared contracts deployments, set the `SPOKE_STRAT_INPUT_FILENAME` and `SPOKE_STRAT_OUTPUT_FILENAME` values in your `.env` file. The `VIEW_MODE` setting applies as described for the hub chain.

#### Spoke Caliber instance

1. Copy `script/deployments/inputs/spoke-calibers/TEMPLATE.json` to `script/deployments/inputs/spoke-calibers/{SPOKE_STRAT_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/spoke-calibers/{SPOKE_STRAT_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeploySpokeCaliber.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

## Timelock Controller Deployment

Set the `TIMELOCK_CONTROLLER_INPUT_FILENAME` and `TIMELOCK_CONTROLLER_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

1. Copy `script/deployments/inputs/timelock-controllers/TEMPLATE.json` to `script/deployments/inputs/timelock-controllers/{TIMELOCK_CONTROLLER_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/timelock-controllers/{TIMELOCK_CONTROLLER_OUTPUT_FILENAME}`.

```shell
forge script script/deployments/DeployTimelockController.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

Some strategy risk functions are intended to be restricted to an external timelock contract. This repo provides a script to deploy an OpenZeppelin's [`TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) contract, prior to strategy deployment.
