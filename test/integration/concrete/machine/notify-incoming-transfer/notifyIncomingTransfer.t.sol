// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract NotifyIncomingTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotMailbox() public {
        vm.expectRevert(IMachine.NotMailbox.selector);
        machine.notifyIncomingTransfer(address(0));
    }

    function test_NotifyIncomingTransfer_EmptyBalance() public {
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(baseToken));
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_NotifyIncomingTransfer_EmptyBalanceAndNonPriceableToken() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(baseToken2));
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_NotifyIncomingTransfer_AccountingToken() public {
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(machine), inputAmount, true);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_ProvidedTokenNonPriceable() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        deal(address(baseToken2), address(machine), inputAmount, true);
        vm.prank(machine.getMailbox(block.chainid));
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        machine.notifyIncomingTransfer(address(baseToken2));
    }

    function test_NotifyIncomingTransfer_BaseToken() public {
        uint256 inputAmount = 1;
        deal(address(baseToken), address(machine), inputAmount, true);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(baseToken));
        assertTrue(machine.isIdleToken(address(baseToken)));
    }
}
