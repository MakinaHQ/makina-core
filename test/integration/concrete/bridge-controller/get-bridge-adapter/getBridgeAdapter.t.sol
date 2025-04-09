// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract GetBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        bridgeController.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);
    }

    function test_GetBridgeAdapter() public {
        vm.prank(dao);
        address adapter = bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");

        assertEq(adapter, bridgeController.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
