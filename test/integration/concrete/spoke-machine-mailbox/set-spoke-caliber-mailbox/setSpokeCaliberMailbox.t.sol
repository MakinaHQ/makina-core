// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachineMailbox} from "src/interfaces/IMachineMailbox.sol";
import {ISpokeMachineMailbox} from "src/interfaces/ISpokeMachineMailbox.sol";
import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";

import {Integration_Concrete_Hub_Test} from "../../IntegrationConcrete.t.sol";

contract SetSpokeCaliberMailbox_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    SpokeMachineMailbox public spokeMachineMailbox;

    function setUp() public override {
        super.setUp();
        vm.prank(dao);
        spokeMachineMailbox = SpokeMachineMailbox(machine.createSpokeMailbox(SPOKE_CHAIN_ID));
    }

    function test_RevertWhen_CallerNotMachine() public {
        vm.expectRevert(IMachineMailbox.NotMachine.selector);
        spokeMachineMailbox.setSpokeCaliberMailbox(address(0));
    }

    function test_RevertWhen_MailboxAlreadySet() public {
        address spokeCaliberMailbox = makeAddr("spokeCaliberMailbox");

        vm.startPrank(address(machine));

        spokeMachineMailbox.setSpokeCaliberMailbox(spokeCaliberMailbox);

        spokeCaliberMailbox = makeAddr("spokeCaliberMailbox2");
        vm.expectRevert(ISpokeMachineMailbox.SpokeCaliberMailboxAlreadySet.selector);
        spokeMachineMailbox.setSpokeCaliberMailbox(spokeCaliberMailbox);
    }

    function test_SetSpokeCaliberMailbox() public {
        address spokeCaliberMailbox = makeAddr("spokeCaliberMailbox");

        vm.prank(address(machine));
        vm.expectEmit(false, false, false, true, address(spokeMachineMailbox));
        emit ISpokeMachineMailbox.SpokeCaliberMailboxSet(spokeCaliberMailbox);
        spokeMachineMailbox.setSpokeCaliberMailbox(spokeCaliberMailbox);

        assertEq(spokeMachineMailbox.spokeCaliberMailbox(), spokeCaliberMailbox);
    }
}
