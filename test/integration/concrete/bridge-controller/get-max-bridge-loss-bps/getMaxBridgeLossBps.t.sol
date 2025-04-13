// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract GetMaxBridgeLossBps_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        bridgeController.getMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3);
    }

    function test_GetMaxBridgeLossBps() public {
        vm.prank(dao);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS, bridgeController.getMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
