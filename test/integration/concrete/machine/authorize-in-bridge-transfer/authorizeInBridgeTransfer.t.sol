// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract AuthorizeInBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        bridgeAdapter = IBridgeAdapter(machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, ""));
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));

        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer() public {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.AuthorizeInBridgeTransfer(messageHash);
        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));

        vm.prank(mechanic);
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.AuthorizeInBridgeTransfer(messageHash);
        vm.prank(securityCouncil);
        machine.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);
    }
}
