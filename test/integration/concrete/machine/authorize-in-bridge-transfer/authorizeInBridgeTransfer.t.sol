// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract AuthorizeInBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter internal bridgeAdapter;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer() public {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.InBridgeTransferAuthorized(messageHash);
        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.InBridgeTransferAuthorized(messageHash);
        vm.prank(securityCouncil);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
    }
}
