# Makina Access Control

## User Roles and Abilities

### Anyone

- Can run authorized accounting instructions in calibers.
- Can submit accounting data from a Spoke Caliber to the Machine, provided it is signed by Wormhole Guardians via the Wormhole CCQ network.
- Can update the total AUM of the Machine, as long as all Caliber accounting data is up to date.

## Roles Permissions List

This is the list of role permissions in Makina Core contracts. These roles must be assigned to respective contracts at deployment.

### HubCoreRegistry

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set address of OracleRegistry.
  - Can set address of TokenRegistry.
  - Can set address of ChainRegistry.
  - Can set address of SwapModule.
  - Can set address of FlashLoanModule.
  - Can set address of HubCoreFactory.
  - Can set address of MachinenBeacon.
  - Can set address of Caliber Beacon.
  - Can set address of PreDepositVault Beacon.
  - Can set address of BridgeAdapter Beacons.

### SpokeCoreRegistry

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set address of OracleRegistry.
  - Can set address of TokenRegistry.
  - Can set address of SwapModule.
  - Can set address of FlashLoanModule.
  - Can set address of SpokeCoreFactory.
  - Can set address of Caliber Beacon.
  - Can set address of CaliberMailbox Beacon.
  - Can set address of BridgeAdapter Beacons.

### OracleRegistry

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set token price feed route.
  - Can set feeds staleness threshold.

### ChainRegistry

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set mappings of EVM and WH chain IDs.

### TokenRegistry

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set mappings of local and foreign token addresses.

### HubCoreFactory

- `STRATEGY_DEPLOYMENT_ROLE` (roleId `2`)
  - Can deploy machine shares.
  - Can deploy pre-deposit vaults.
  - Can deploy machines and calibers.

### SpokeCoreFactory

- `STRATEGY_DEPLOYMENT_ROLE` (roleId `2`)
  - Can deploy calibers.

### SwapModule

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set approval and execution targets for a given swapper ID.

### AcrossV2BridgeConfig

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set supported status of EVM chains.
  
### LayerZeroV2Config

- `INFRA_SETUP_ROLE` (roleId `1`)
  - Can set mappings of EVM and LZ chain IDs.
  - Can set mappings of tokens to corresponding LZ OFTs.

### Machine

- `STRATEGY_COMPONENTS_SETUP_ROLE` (roleId `3`)

  - Can set the address of a Spoke caliber mailbox.
  - Can create a bridge adapter.
  - Can set the address of a Spoke bridge adapter.
  - Can set the address of the depositor contract.
  - Can set the address of the redeemer contract.
  - Can set the address of the fee manager contract.

- `STRATEGY_MANAGEMENT_SETUP_ROLE` (roleId `4`)

  - Can set the address of the mechanic.
  - Can set the address of the security council.
  - Can set the address of the risk manager.
  - Can set the address of the risk manager timelock.

- **Security Council**

  - Can trigger recovery mode.
  - Can reset the bridging state for any token.

- **Risk Manager**

  - Can set the share token supply limit that cannot be exceeded by new deposits.

- **Risk Manager Timelock**

  - Can set the outgoing transfer enabled status for a bridge.
  - Can set the maximum allowed value loss in basis points for a bridge.
  - Can set the caliber accounting staleness threshold.
  - Can set the maximum fixed and perf fee accrual rates.
  - Can set the minimum time to be elapsed between two fee minting events.

- **Mechanic / Security Council**

  The following permissions are attributed to mechanic by default, and passed on to the security council when recovery mode is triggered.

  - Can schedule an outgoing bridge transfer towards a spoke caliber (only when not in recovery mode).
  - Can cancel an outgoing bridge transfer.
  - Can send an outgoing bridge transfer (only when not in recovery mode).
  - Can authorize an incoming bridge transfer from a spoke caliber.
  - Can claim an incoming bridge transfer from a spoke caliber.

### Pre-Deposit Vault

- `STRATEGY_MANAGEMENT_SETUP_ROLE` (roleId `4`)

  - Can set the address of the risk manager.

- **Risk Manager**
  - Can set the share token supply limit that cannot be exceeded by new deposits.
  - Can add or remove users from the whitelist for deposits and redemptions.
  - Can enable or disable the whitelist.

### Caliber Mailbox

- `STRATEGY_COMPONENTS_SETUP_ROLE` (roleId `3`)

  - Can create a bridge adapter.
  - Can set the address of a Hub bridge adapter.

- `STRATEGY_MANAGEMENT_SETUP_ROLE` (roleId `4`)

  - Can set the address of the mechanic.
  - Can set the address of the security council.
  - Can set the address of the risk manager.
  - Can set the address of the risk manager timelock.

- **Security Council**

  - Can trigger recovery mode.
  - Can reset the bridging state for any token.

- **Risk Manager Timelock**

  - Can set the outgoing transfer enabled status for a bridge.
  - Can set the maximum allowed value loss in basis points for a bridge.

- **Mechanic / Security Council**

  The following permissions are attributed to mechanic by default, and passed on to the security council when recovery mode is triggered.

  - Can schedule outgoing bridge transfer towards the Hub Machine.
  - Can cancel outgoing bridge transfer.
  - Can send outgoing bridge transfer.
  - Can authorize incoming bridge transfer from the Hub Machine.
  - Can claim incoming bridge transfer from the Hub Machine.

### Caliber

- `STRATEGY_MANAGEMENT_SETUP_ROLE` (roleId `4`)

  - Can add and remove Merkle root guardians.

- **Risk Manager**

  - Can schedule an update of the root of the Merkle tree containing allowed instructions.

- **Root Guardians**

  - Can veto an update of the root of the Merkle tree containing allowed instructions.

- **Risk Manager Timelock**

  - Can register and unregister base tokens.
  - Can set the position accounting staleness threshold.
  - Can set the timelock duration for the allowed instruction merkle root update.
  - Can set the max allowed value loss for position increases.
  - Can set the max allowed value loss for position decreases.
  - Can set the max allowed loss for base token swaps.

- **Mechanic / Security Council**

  The following permissions are attributed to mechanic by default, and passed on to the security council when recovery mode is triggered.

  - Can open, manage and close positions (position increases allowed only when not in recovery mode).
  - Can harvest external rewards.
  - Can swap tokens towards any base token.
  - Can initiate a transfer towards hub machine endpoint.
