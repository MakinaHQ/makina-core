// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "./IMachineMailbox.sol";

interface ISpokeMachineMailbox is IMachineMailbox {
    error SpokeCaliberMailboxAlreadySet();

    event SpokeCaliberMailboxSet(address spokeCaliberMailbox);

    /// @notice Initializer of the contract.
    /// @param _machine Address of the associated machine.
    /// @param _spokeChainId Chain ID of the spoke.
    function initialize(address _machine, uint256 _spokeChainId) external;

    /// @notice Chain ID of the spoke.
    function spokeChainId() external view returns (uint256);

    /// @notice Address of the associated spoke caliber mailbox.
    function spokeCaliberMailbox() external view returns (address);

    /// @notice Set the address of the associated spoke caliber mailbox.
    /// @param _spokeCaliberMailbox Address of the spoke caliber mailbox.
    function setSpokeCaliberMailbox(address _spokeCaliberMailbox) external;
}
