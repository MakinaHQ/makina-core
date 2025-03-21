// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {ISpokeMachineMailbox} from "src/interfaces/ISpokeMachineMailbox.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract SetSpokeCaliberMailbox_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setSpokeCaliberMailbox(SPOKE_CHAIN_ID, address(0));
    }

    function test_RevertGiven_MachineMailboxDoesNotExist() public {
        vm.startPrank(dao);
        vm.expectRevert(IMachine.MachineMailboxDoesNotExist.selector);
        machine.setSpokeCaliberMailbox(SPOKE_CHAIN_ID, address(0));
    }

    function test_SetSpokeCaliberMailbox() public {
        address spokeCaliberMailbox = makeAddr("spokeCaliberMailbox");

        vm.startPrank(dao);
        address mailbox = machine.createSpokeMailbox(SPOKE_CHAIN_ID);
        machine.setSpokeCaliberMailbox(SPOKE_CHAIN_ID, spokeCaliberMailbox);

        assertEq(ISpokeMachineMailbox(mailbox).spokeCaliberMailbox(), spokeCaliberMailbox);
    }
}
