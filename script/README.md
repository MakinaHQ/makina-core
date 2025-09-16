# Deploy Makina Core

This README outlines the steps to deploy the Makina Core contracts.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs, Etherscan API URLs, and API keys.
- Some networks are preconfigured in `foundry.toml` and only require the corresponding environment variables. More networks can be added following similar configuration.
- The commands below use a foundry keystore to specify the deployment wallet (`--account <keystore-name>`). For other options, refer to the [Foundry docs](https://getfoundry.sh/forge/reference/script/).
- Notation used in the commands:
  - `<keystore-name>` - the name of a Foundry keystore containing the deployer’s private key
  - `<network-alias>` - must match a network name declared in `foundry.toml`

## Hub Chain Deployments

Set the `HUB_INPUT_FILE` and `HUB_OUTPUT_FILE` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

### Shared contracts

1. Copy `script/deployments/inputs/hub-cores/TEMPLATE.json` to `script/deployments/inputs/hub-cores/{HUB_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-cores/{HUB_INPUT_FILENAME}` containing the deployed contract addresses.

```
forge script script/deployments/DeployHubCore.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

Note: This script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx).

### Hub Machine instance

1. Copy `script/deployments/inputs/hub-machines/TEMPLATE.json` to `script/deployments/inputs/hub-machines/{HUB_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-machines/{HUB_INPUT_FILENAME}`.

```
forge script script/deployments/DeployHubMachine.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

### Pre-Deposit Vault instance

1. Copy `script/deployments/inputs/pre-deposit-vaults/TEMPLATE.json` to `script/deployments/inputs/pre-deposit-vaults/{HUB_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/pre-deposit-vaults/{HUB_INPUT_FILENAME}`.

```
forge script script/deployments/DeployPreDepositVault.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

### Pre-Deposit Vault instance migration into Hub Machine instance

1. Copy `script/deployments/inputs/pre-deposit-migrations/TEMPLATE.json` to `script/deployments/inputs/pre-deposit-migrations/{HUB_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/pre-deposit-migrations/{HUB_INPUT_FILENAME}`.

```
forge script script/deployments/DeployHubMachineFromPreDeposit.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

## Spoke Chain Deployments

Set the `SPOKE_INPUT_FILE` and `SPOKE_OUTPUT_FILE` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Base Mainnet, both of these files can be named `Base.json`.

### Shared contracts

1. Copy `script/deployments/inputs/spoke-cores/TEMPLATE.json` to `script/deployments/inputs/spoke-cores/{SPOKE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/spoke-cores/{SPOKE_INPUT_FILENAME}`.

```
forge script script/deployments/DeploySpokeCore.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

Note: Same as for Hub Chain shared contacts deployment, this script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx).

### Spoke Caliber instance

1. Copy `script/deployments/inputs/spoke-calibers/TEMPLATE.json` to `script/deployments/inputs/spoke-calibers/{SPOKE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/spoke-calibers/{SPOKE_INPUT_FILENAME}`.

```
forge script script/deployments/DeploySpokeCaliber.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

## Timelock Controller Deployment

Set the `TIMELOCK_CONTROLLER_INPUT_FILENAME` and `TIMELOCK_CONTROLLER_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

1. Copy `script/deployments/inputs/spoke-calibers/TEMPLATE.json` to `script/deployments/inputs/timelock-controllers/{TIMELOCK_CONTROLLER_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/timelock-controllers/{TIMELOCK_CONTROLLER_OUTPUT_FILENAME}`.

```
forge script script/deployments/DeployTimelockController.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

Some strategy risk functions are intended to be restricted to an external timelock contract. This repo provides a script to deploy an OpenZeppelin's [`TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) contract, prior to strategy deployment.
