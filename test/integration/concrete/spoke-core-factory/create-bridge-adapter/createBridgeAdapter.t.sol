// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {Errors} from "src/libraries/Errors.sol";

import {SpokeCoreFactory_Integration_Concrete_Test} from "../SpokeCoreFactory.t.sol";

contract CreateBridgeAdapter_Integration_Concrete_Test is SpokeCoreFactory_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        spokeCoreFactory.createBridgeAdapter(address(0), baParams);
    }

    function test_RevertWhen_InvalidBridgeController() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.prank(dao);
        vm.expectRevert(Errors.InvalidBridgeController.selector);
        spokeCoreFactory.createBridgeAdapter(address(0), baParams);
    }

    function test_RevertWhen_BridgeIdUnsupported() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams;

        vm.expectRevert(Errors.InvalidBridgeId.selector);
        vm.prank(dao);
        spokeCoreFactory.createBridgeAdapter(address(caliberMailbox), baParams);
    }

    function test_CreateBridgeAdapter() public {
        IBridgeAdapterFactory.BridgeAdapterInitParams memory baParams = IBridgeAdapterFactory.BridgeAdapterInitParams({
            bridgeId: ACROSS_V3_BRIDGE_ID,
            initData: "",
            initialMaxBridgeLossBps: DEFAULT_MAX_BRIDGE_LOSS_BPS
        });

        vm.expectEmit(true, true, false, false, address(spokeCoreFactory));
        emit IBridgeAdapterFactory.BridgeAdapterCreated(address(caliberMailbox), ACROSS_V3_BRIDGE_ID, address(0));
        vm.prank(dao);
        address bridgeAdapter = spokeCoreFactory.createBridgeAdapter(address(caliberMailbox), baParams);

        assertTrue(bridgeAdapter != address(0));
        assertTrue(spokeCoreFactory.isBridgeAdapter(bridgeAdapter));

        assertTrue(caliberMailbox.isBridgeSupported(ACROSS_V3_BRIDGE_ID));
        assertTrue(caliberMailbox.isOutTransferEnabled(ACROSS_V3_BRIDGE_ID));
        assertEq(caliberMailbox.getBridgeAdapter(ACROSS_V3_BRIDGE_ID), bridgeAdapter);
        assertEq(caliberMailbox.getMaxBridgeLossBps(ACROSS_V3_BRIDGE_ID), DEFAULT_MAX_BRIDGE_LOSS_BPS);

        assertEq(IBridgeAdapter(bridgeAdapter).controller(), address(caliberMailbox));
    }
}
