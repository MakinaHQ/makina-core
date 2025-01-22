// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBaseMakinaRegistry} from "./IBaseMakinaRegistry.sol";

interface IHubRegistry is IBaseMakinaRegistry {
    event MachineBeaconChange(address indexed oldMachineBeacon, address indexed newMachineBeacon);
    event MachineFactoryChange(address indexed oldMachineFactory, address indexed newMachineFactory);
    event HubDualMailboxBeaconChange(address indexed oldHubDualMailboxBeacon, address indexed newHubDualMailboxBeacon);

    /// @notice Address of the machine factory.
    function machineFactory() external view returns (address);

    /// @notice Address of the machine beacon contract.
    function machineBeacon() external view returns (address);

    /// @notice Address of the hub dual mailbox beacon contract.
    function hubDualMailboxBeacon() external view returns (address);

    /// @notice Sets the machine factory address.
    /// @param _machineFactory The machine factory address.
    function setMachineFactory(address _machineFactory) external;

    /// @notice Sets the machine beacon address.
    /// @param _machineBeacon The machine beacon address.
    function setMachineBeacon(address _machineBeacon) external;

    /// @notice Sets the hub dual mailbox beacon address.
    /// @param _hubDualMailboxBeacon The machine hub dual mailbox beacon address.
    function setHubDualMailboxBeacon(address _hubDualMailboxBeacon) external;
}
