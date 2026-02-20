// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetMaxBridgeLossBps_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        bridgeController.setMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(riskManagerTimelock);
        bridgeController.setMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_SetMaxBridgeLossBps() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        vm.expectEmit(true, true, true, false, address(bridgeController));
        emit IBridgeController.MaxBridgeLossBpsChanged(
            ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2
        );
        vm.prank(riskManagerTimelock);
        bridgeController.setMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2);

        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS * 2, bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID));
    }
}
