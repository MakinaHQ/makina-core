// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract IsOutTransferEnabled_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_IsOutTransferEnabled() public {
        assertFalse(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));

        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
    }
}
