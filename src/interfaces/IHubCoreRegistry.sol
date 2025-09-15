// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICoreRegistry} from "./ICoreRegistry.sol";

interface IHubCoreRegistry is ICoreRegistry {
    event ChainRegistryChanged(address indexed oldChainRegistry, address indexed newChainRegistry);
    event MachineBeaconChanged(address indexed oldMachineBeacon, address indexed newMachineBeacon);
    event PreDepositVaultBeaconChanged(
        address indexed oldPreDepositVaultBeacon, address indexed newPreDepositVaultBeacon
    );

    /// @notice Address of the chain registry.
    function chainRegistry() external view returns (address);

    /// @notice Address of the machine beacon contract.
    function machineBeacon() external view returns (address);

    /// @notice Address of the pre-deposit vault beacon contract.
    function preDepositVaultBeacon() external view returns (address);

    /// @notice Sets the chain registry address.
    /// @param _chainRegistry The chain registry address.
    function setChainRegistry(address _chainRegistry) external;

    /// @notice Sets the machine beacon address.
    /// @param _machineBeacon The machine beacon address.
    function setMachineBeacon(address _machineBeacon) external;

    /// @notice Sets the pre-deposit vault beacon address.
    /// @param _preDepositVaultBeacon The pre-deposit vault beacon address.
    function setPreDepositVaultBeacon(address _preDepositVaultBeacon) external;
}
