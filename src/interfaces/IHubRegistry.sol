// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {IBaseMakinaRegistry} from "./IBaseMakinaRegistry.sol";

interface IHubRegistry is IBaseMakinaRegistry {
    event MachineFactoryChange(address indexed oldMachineFactory, address indexed newMachineFactory);
    event MachineBeaconChange(address indexed oldMachineBeacon, address indexed newMachineBeacon);
    event MachineHubInboxBeaconChange(
        address indexed oldMachineHubInboxBeacon, address indexed newMachineHubInboxBeacon
    );

    struct initParams {
        address oracleRegistry;
        address swapper;
        address initialAuthority;
    }

    /// @notice Address of the machine factory
    function machineFactory() external view returns (address);

    /// @notice Address of the machine beacon contract
    function machineBeacon() external view returns (address);

    /// @notice Address of the machine hub inbox beacon contract
    function machineHubInboxBeacon() external view returns (address);

    /// @notice Sets the machine factory address
    /// @param _machineFactory Machine factory address
    function setMachineFactory(address _machineFactory) external;

    /// @notice Sets the machine beacon address
    /// @param _machineBeacon Machine beacon address
    function setMachineBeacon(address _machineBeacon) external;

    /// @notice Sets the machine hub inbox beacon address
    /// @param _machineHubInboxBeacon Machine hub inbox beacon address
    function setMachineHubInboxBeacon(address _machineHubInboxBeacon) external;
}
