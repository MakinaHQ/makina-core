// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract AuthorizeInBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        bridgeAdapter = IBridgeAdapter(
            caliberMailbox.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "")
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer() public {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.AuthorizeInBridgeTransfer(messageHash);
        vm.prank(mechanic);
        caliberMailbox.authorizeInBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, messageHash);
    }
}
