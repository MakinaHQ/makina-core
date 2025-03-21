// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "./IMachine.sol";

interface IMachineFactory {
    event MachineDeployed(address indexed machine);
    event ShareTokenDeployed(address indexed shareToken);

    /// @notice Address of the registry.
    function registry() external view returns (address);

    /// @notice Machine => whether the machine was deployed by this factory
    function isMachine(address machine) external view returns (bool);

    /// @notice Machine => whether the caliber was deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new Machine instance.
    /// @param params The initialization parameters.
    /// @param tokenName The name of the share token.
    /// @param tokenSymbol The symbol of the share token.
    /// @return machine The address of the deployed Machine instance.
    function createMachine(
        IMachine.MachineInitParams calldata params,
        string memory tokenName,
        string memory tokenSymbol
    ) external returns (address machine);
}
