// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract GetMaxBridgeLossBps_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID);
    }

    function test_GetMaxBridgeLossBps() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS, bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID));
    }
}
