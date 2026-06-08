// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract EnableOutTransfer_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeController.enableOutTransfer(ACROSS_V3_BRIDGE_ID);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(riskManagerTimelock);
        bridgeController.enableOutTransfer(ACROSS_V3_BRIDGE_ID);
    }

    function test_RevertWhen_AlreadyEnabled() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        vm.expectRevert(Errors.AlreadyEnabled.selector);
        vm.prank(riskManagerTimelock);
        bridgeController.enableOutTransfer(ACROSS_V3_BRIDGE_ID);
    }

    function test_EnableOutTransfer() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        vm.prank(riskManagerTimelock);
        bridgeController.disableOutTransfer(ACROSS_V3_BRIDGE_ID);
        assertFalse(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));

        vm.expectEmit(true, false, false, false, address(bridgeController));
        emit IBridgeController.OutTransferEnabled(ACROSS_V3_BRIDGE_ID);
        vm.prank(riskManagerTimelock);
        bridgeController.enableOutTransfer(ACROSS_V3_BRIDGE_ID);
        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
    }
}
