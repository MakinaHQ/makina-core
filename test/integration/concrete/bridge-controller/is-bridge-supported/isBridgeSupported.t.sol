// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract IsBridgeSupported_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_IsBridgeSupported() public {
        assertFalse(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));

        vm.prank(dao);
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertTrue(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));
    }
}
