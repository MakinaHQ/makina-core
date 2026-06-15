// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract GetBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_RevertWhen_InvalidBridgeId() public {
        vm.expectRevert(Errors.InvalidBridgeId.selector);
        bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
    }

    function test_GetBridgeAdapter() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertEq(bridgeAdapter, bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID));
    }
}
