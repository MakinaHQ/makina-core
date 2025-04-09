// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract IsBridgeSupported_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_IsBridgeSupported() public {
        assertFalse(bridgeController.isBridgeSupported(IBridgeAdapter.Bridge.ACROSS_V3));

        vm.prank(dao);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");

        assertTrue(bridgeController.isBridgeSupported(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
