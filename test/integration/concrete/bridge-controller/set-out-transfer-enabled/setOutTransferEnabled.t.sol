// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetOutTransferEnabled_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(dao);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
    }

    function test_SetOutTransferEnabled() public {
        vm.prank(dao);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, "");

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.SetOutTransferEnabled(uint256(IBridgeAdapter.Bridge.ACROSS_V3), false);
        vm.prank(dao);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
        assertFalse(bridgeController.isOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3));

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.SetOutTransferEnabled(uint256(IBridgeAdapter.Bridge.ACROSS_V3), true);
        vm.prank(dao);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, true);
        assertTrue(bridgeController.isOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
