// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract AuthorizeInBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    address internal bridgeAdapter;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.prank(dao);
        bridgeAdapter = spokeCoreFactory.createBridgeAdapter(
            address(caliberMailbox),
            IBridgeAdapterFactory.BridgeAdapterInitParams(ACROSS_V3_BRIDGE_ID, "", DEFAULT_MAX_BRIDGE_LOSS_BPS)
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.RecoveryMode.selector);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, bytes32(0));
    }

    function test_AuthorizeInBridgeTransfer() public {
        bytes32 messageHash = bytes32("12345");

        vm.expectEmit(true, false, false, false, bridgeAdapter);
        emit IBridgeAdapter.InBridgeTransferAuthorized(messageHash);
        vm.prank(mechanic);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);
    }
}
