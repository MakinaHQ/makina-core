// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {BridgeController_Integration_Concrete_Test} from "../BridgeController.t.sol";

abstract contract SetOutTransferEnabled_Integration_Concrete_Test is BridgeController_Integration_Concrete_Test {
    function setUp() public virtual override {
        BridgeController_Integration_Concrete_Test.setUp();
    }

    function test_RevertWhen_CallerNotRMT() public {
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
    }

    function test_SetOutTransferEnabled() public {
        vm.prank(dao);
        bridgeController.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "");

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.SetOutTransferEnabled(uint256(IBridgeAdapter.Bridge.ACROSS_V3), false);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);
        assertFalse(bridgeController.isOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3));

        vm.expectEmit(true, true, false, false, address(bridgeController));
        emit IBridgeController.SetOutTransferEnabled(uint256(IBridgeAdapter.Bridge.ACROSS_V3), true);
        vm.prank(riskManagerTimelock);
        bridgeController.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, true);
        assertTrue(bridgeController.isOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
