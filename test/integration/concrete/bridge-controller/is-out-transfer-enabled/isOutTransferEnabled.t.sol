// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract IsOutTransferEnabled_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_IsOutTransferEnabled() public {
        assertFalse(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));

        vm.prank(dao);
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
    }
}
