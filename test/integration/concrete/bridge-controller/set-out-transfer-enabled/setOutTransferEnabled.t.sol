// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetOutTransferEnabled_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeController.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);
    }

    function test_SetOutTransferEnabled() public {
        vm.prank(dao);
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.OutTransferEnabledSet(ACROSS_V3_BRIDGE_ID, false);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);
        assertFalse(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.OutTransferEnabledSet(ACROSS_V3_BRIDGE_ID, true);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, true);
        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
    }
}
