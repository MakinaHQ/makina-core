// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetMaxBridgeLossBps_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

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
        vm.prank(dao);
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectEmit(true, true, true, false, address(bridgeController));
        emit IBridgeController.MaxBridgeLossBpsChange(
            ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2
        );
        vm.prank(riskManagerTimelock);
        bridgeController.setMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2);

        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS * 2, bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID));
    }
}
