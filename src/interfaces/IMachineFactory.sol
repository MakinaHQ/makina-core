// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "./IMachine.sol";

interface IMachineFactory {
    event MachineDeployed(address indexed machine);

    /// @notice Address of the registry.
    function registry() external view returns (address);

    /// @notice Machine => whether the machine was deployed by this factory
    function isMachine(address machine) external view returns (bool);

    /// @notice Deploys a new Machine instance.
    /// @param params The initialization parameters.
    /// @return machine The address of the deployed Machine instance.
    function deployMachine(IMachine.MachineInitParams calldata params) external returns (address machine);
}
