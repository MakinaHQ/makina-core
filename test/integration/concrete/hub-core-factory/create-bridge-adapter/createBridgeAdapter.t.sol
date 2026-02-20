// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {Errors} from "src/libraries/Errors.sol";

import {HubCoreFactory_Integration_Concrete_Test} from "../HubCoreFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is HubCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        hubCoreFactory.createBridgeAdapter(address(0), baParams);
    }

    function test_RevertWhen_InvalidBridgeController() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.prank(dao);
        vm.expectRevert(Errors.InvalidBridgeController.selector);
        hubCoreFactory.createBridgeAdapter(address(0), baParams);
    }

    function test_RevertWhen_BridgeIdUnsupported() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.expectRevert(Errors.InvalidBridgeId.selector);
        vm.prank(dao);
        hubCoreFactory.createBridgeAdapter(address(machine), baParams);
    }

    function test_CreateBridgeAdapter() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams = IBridgeAdapterFactory.BridgeAdapterInitParams({
            bridgeId: ACROSS_V3_BRIDGE_ID,
            initData: "",
            initialMaxBridgeLossBps: DEFAULT_MAX_BRIDGE_LOSS_BPS
        });

        vm.expectEmit(true, true, false, false, address(hubCoreFactory));
        emit IBridgeAdapterFactory.BridgeAdapterCreated(address(machine), ACROSS_V3_BRIDGE_ID, address(0));
        vm.prank(dao);
        address bridgeAdapter = hubCoreFactory.createBridgeAdapter(address(machine), baParams);

        assertTrue(bridgeAdapter != address(0));
        assertTrue(hubCoreFactory.isBridgeAdapter(bridgeAdapter));

        assertTrue(machine.isBridgeSupported(ACROSS_V3_BRIDGE_ID));
        assertTrue(machine.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
        assertEq(machine.getBridgeAdapter(ACROSS_V3_BRIDGE_ID), bridgeAdapter);
        assertEq(machine.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID), DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertEq(IBridgeAdapter(bridgeAdapter).controller(), address(machine));
    }
}
