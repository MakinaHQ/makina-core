// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {Errors} from "src/libraries/Errors.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetBridgeAdapter_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotFactory() public {
        vm.expectRevert(Errors.NotFactory.selector);
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, address(0), DEFAULT_MAX_BRIDGE_LOSS_BPS);
    }

    function test_RevertGiven_BridgeAdapterAlreadyExists() public {
        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.startPrank(address(coreFactory));

        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        vm.expectRevert(Errors.BridgeAdapterAlreadyExists.selector);
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);
    }

    function test_RevertGiven_ZeroBridgeAdapterAddress() public {
        vm.startPrank(address(coreFactory));

        vm.expectRevert(Errors.ZeroBridgeAdapterAddress.selector);
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, address(0), DEFAULT_MAX_BRIDGE_LOSS_BPS);
    }

    function test_SetBridgeAdapter_acrossV3() public {
        assertFalse(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));

        address beacon = address(_deployAcrossV3BridgeAdapterBeacon(address(accessManager), address(0), address(0)));
        vm.prank(dao);
        registry.setBridgeAdapterBeacon(ACROSS_V3_BRIDGE_ID, beacon);

        address bridgeAdapter = makeAddr("bridgeAdapter");

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.BridgeAdapterSet(ACROSS_V3_BRIDGE_ID, bridgeAdapter);
        vm.prank(address(bridgeAdapterFactory));
        bridgeController.setBridgeAdapter(ACROSS_V3_BRIDGE_ID, bridgeAdapter, DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertTrue(bridgeController.isBridgeSupported(ACROSS_V3_BRIDGE_ID));
        assertTrue(bridgeController.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
        assertEq(bridgeController.getBridgeAdapter(ACROSS_V3_BRIDGE_ID), bridgeAdapter);
        assertEq(bridgeController.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID), DEFAULT_MAX_BRIDGE_LOSS_BPS);
    }
}
