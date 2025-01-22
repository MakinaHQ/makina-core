// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IMailbox {
    /// @notice Initializer of the contract.
    /// @param machineEndpoint The address of the machine endpoint.
    /// @param caliberEndpoint The address of the caliber endpoint.
    function initialize(address machineEndpoint, address caliberEndpoint) external;

    /// @notice Manages the transfer of tokens from the machine to the caliber.
    /// @param token The address of the token.
    /// @param amount The amount of tokens to transfer.
    function manageTransferFromMachineToCaliber(address token, uint256 amount) external;

    /// @notice Manages the transfer of tokens from the caliber to the machine.
    /// @param token The address of the token.
    /// @param amount The amount of tokens to transfer.
    function manageTransferFromCaliberToMachine(address token, uint256 amount) external;
}
