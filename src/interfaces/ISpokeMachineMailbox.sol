// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "./IMachineMailbox.sol";

interface ISpokeMachineMailbox is IMachineMailbox {
    error SpokeCaliberMailboxAlreadySet();
    
    /// @notice Chain ID of the spoke.
    function spokeChainId() external view returns (uint256);

    /// @notice Address of the associated spoke caliber mailbox.
    function spokeCaliberMailbox() external view returns (address);
}
