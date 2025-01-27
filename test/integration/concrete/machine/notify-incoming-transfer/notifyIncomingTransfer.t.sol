// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract NotifyIncomingTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_cannotNotifyIncomingTransferWithoutMailbox() public {
        vm.expectRevert(IMachine.NotMailbox.selector);
        machine.notifyIncomingTransfer(address(0));
    }

    function test_cannotNotifyIncomingTransferWithoutPriceableToken() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.prank(machine.getMailbox(block.chainid));
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        machine.notifyIncomingTransfer(address(baseToken2));
    }

    function test_notifyIncomingTransferWithEmptyBalance() public {
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));
        assertFalse(machine.isIdleToken(address(accountingToken)));
    }

    function test_notifyIncomingTransfer() public {
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(machine), inputAmount, true);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }
}
