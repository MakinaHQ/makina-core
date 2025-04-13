// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract CreateBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
    }

    function test_RevertGiven_BridgeAdapterAlreadyExists() public {
        vm.startPrank(address(dao));

        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectRevert(IBridgeController.BridgeAdapterAlreadyExists.selector);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
    }

    function test_createBridgeAdapter_acrossV3() public {
        assertFalse(bridgeController.isBridgeSupported(IBridgeAdapter.Bridge.ACROSS_V3));

        address beacon = address(_deployAccrossV3BridgeAdapterBeacon(dao, address(0)));
        vm.prank(dao);
        registry.setBridgeAdapterBeacon(IBridgeAdapter.Bridge.ACROSS_V3, beacon);

        vm.expectEmit(true, false, false, false, address(bridgeController));
        emit IBridgeController.BridgeAdapterCreated(uint256(IBridgeAdapter.Bridge.ACROSS_V3), address(0));
        vm.prank(dao);
        address adapter =
            bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertTrue(bridgeController.isBridgeSupported(IBridgeAdapter.Bridge.ACROSS_V3));
        assertTrue(bridgeController.isOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3));
        assertEq(adapter, bridgeController.getBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3));
        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS, bridgeController.getMaxBridgeLossBps(IBridgeAdapter.Bridge.ACROSS_V3));
        assertEq(IBridgeAdapter(adapter).controller(), address(bridgeController));
        assertEq(IBridgeAdapter(adapter).bridgeId(), uint256(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
