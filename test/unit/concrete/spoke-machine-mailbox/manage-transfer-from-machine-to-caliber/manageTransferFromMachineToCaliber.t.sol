// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "src/interfaces/IMachineMailbox.sol";
import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";

import {SpokeMachineMailbox_Unit_Concrete_Test} from "../SpokeMachineMailbox.t.sol";

contract ManageTransferFromMachineToCaliber_Unit_Concrete_Test is SpokeMachineMailbox_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotMachine() public {
        vm.expectRevert(IMachineMailbox.NotMachine.selector);
        spokeMachineMailbox.manageTransferFromMachineToCaliber(address(accountingToken), 1e18);
    }

    // @TODO
    function test_ManageTransferFromMachineToCaliber() public {
        vm.prank(address(machine));
        spokeMachineMailbox.manageTransferFromMachineToCaliber(address(accountingToken), 1e18);
    }
}
