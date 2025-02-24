// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {ISpokeMachineMailbox} from "src/interfaces/ISpokeMachineMailbox.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract CreatSpokeMailbox_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.createSpokeMailbox(SPOKE_CHAIN_ID);
    }

    function test_RevertGiven_MailboxAlreadyExists() public {
        vm.startPrank(dao);

        machine.createSpokeMailbox(SPOKE_CHAIN_ID);

        vm.expectRevert(IMachine.SpokeMailboxAlreadyExists.selector);
        machine.createSpokeMailbox(SPOKE_CHAIN_ID);
    }

    function test_CreateSpokeMailbox() public {
        vm.prank(dao);
        vm.expectEmit(false, true, false, false, address(machine));
        emit IMachine.SpokeMailboxDeployed(address(0), SPOKE_CHAIN_ID);
        address mailbox = machine.createSpokeMailbox(SPOKE_CHAIN_ID);

        assertEq(ISpokeMachineMailbox(mailbox).machine(), address(machine));
        IMachine.SpokeCaliberData memory spokeCaliberData = machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(spokeCaliberData.machineMailbox, mailbox);
        assertEq(spokeCaliberData.chainId, SPOKE_CHAIN_ID);
    }
}
