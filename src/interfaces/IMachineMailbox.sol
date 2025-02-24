// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMailbox} from "./IMailbox.sol";

interface IMachineMailbox is IMailbox {
    error NotMachine();

    /// @notice Address of the associated machine.
    function machine() external view returns (address);
}
