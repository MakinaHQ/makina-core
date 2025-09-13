// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IWeirollVM {
    /// @notice Executes a list of commands on the VM.
    /// @param commands The list of commands to execute.
    /// @param state The initial state to pass to the VM.
    /// @return outState The new state after executing the commands.
    function execute(bytes32[] calldata commands, bytes[] memory state) external returns (bytes[] memory);
}
