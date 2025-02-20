// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";

import {SpokeMachineMailbox_Unit_Concrete_Test} from "../SpokeMachineMailbox.t.sol";

contract ManageTransferFromCaliberToMachine_Unit_Concrete_Test is SpokeMachineMailbox_Unit_Concrete_Test {
    // @TODO
    function test_ManageTransferFromCaliberToMachine() public {
        spokeMachineMailbox.manageTransferFromCaliberToMachine(address(accountingToken), 1e18);
    }
}
