// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract CreateBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
    }

    function test_RevertGiven_BridgeAdapterAlreadyExists() public {
        vm.startPrank(address(dao));

        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectRevert(Errors.BridgeAdapterAlreadyExists.selector);
        bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");
    }

    function test_createBridgeAdapter_acrossV3() public {
        assertFalse(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));

        address beacon = address(_deployAcrossV3BridgeAdapterBeacon(address(accessManager), address(0), address(0)));
        vm.prank(dao);
        registry.setBridgeAdapterBeacon(ACROSS_V3_BRIDGE_ID, beacon);

        vm.expectEmit(true, false, false, false, address(bridgeController));
        emit IBridgeController.BridgeAdapterCreated(ACROSS_V3_BRIDGE_ID, address(0));
        vm.prank(dao);
        address adapter = bridgeController.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        assertTrue(bridgeAdapterFactory.isBridgeAdapter(adapter));
        assertTrue(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));
        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
        assertEq(adapter, bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID));
        assertEq(DEFAULT_MAX_BRIDGE_LOSS_BPS, bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID));
        assertEq(IBridgeAdapter(adapter).controller(), address(bridgeController));
        assertEq(IBridgeAdapter(adapter).bridgeId(), ACROSS_V3_BRIDGE_ID);
    }
}
