// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract GetBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID);
    }

    function test_GetBridgeAdapter() public {
        vm.prank(dao);
        address adapter = bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertEq(adapter, bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID));
    }
}
