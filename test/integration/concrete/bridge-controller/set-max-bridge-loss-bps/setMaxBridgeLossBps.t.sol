// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetMaxBridgeLossBps_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        bridgeController.setMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3, 0);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(dao);
        bridgeController.setMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3, 0);
    }

    function test_SetMaxBridgeLossBps() public {
        vm.startPrank(dao);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectEmit(true, true, true, false, address(bridgeController));
        emit IBridgeController.MaxBridgeLossBpsChange(
            uint256(IBridgeAdapter.Bridge.ACROSS_V3), DEFAULT_MAX_BRIDGE_LOSS_BPS, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2
        );
        bridgeController.setMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS * 2);

        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS * 2, bridgeController.getMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
