# Makina Access Control

## Permissions List

This is a list of role permissions in Makina Core contracts. These roles must be assigned to respective contracts at deployment.

### HubCoreRegistry

- `ADMIN_ROLE` (roleId `0`)
  - Can set address of OracleRegistry.
  - Can set address of SwapModule.
  - Can set address of OracleRegistry.
  - Can set address of HubCoreFactory.
  - Can set address of MachineBeacon.
  - Can set address of SpokeCoreFactory.
  - Can set address of CaliberBeacon.

#### OracleRegistry

- `ADMIN_ROLE` (roleId `0`)
  - Can set token price feed route.
  - Can set feeds staleness threshold.

#### SpokeCoreFactory

- `ADMIN_ROLE` (roleId `0`)
  - Can deploy calibers.

#### Caliber

- `ADMIN_ROLE` (roleId `0`)
  - Can add base token.
  - Can set the address of the mechanic.
  - Can set the address of the security council.
  - Can set the position staleness threshold.
  - Can set the recovery mode.
  - Can set the timelock duration for the allowed instruction merkle root update.
  - Can schedule an allowed instruction merkle root update.
  - Can set the max allowed loss for base token swaps.

#### SwapModule

- `ADMIN_ROLE` (roleId `0`)
  - Can set approval and execution targets for a given swapper ID.
