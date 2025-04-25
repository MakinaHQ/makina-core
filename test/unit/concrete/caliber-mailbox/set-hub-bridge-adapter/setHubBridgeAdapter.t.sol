// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract SetHubBridgeAdapter_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(0));
    }

    function test_RevertGiven_HubBridgeAdapterAlreadySet() public {
        vm.startPrank(address(dao));

        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(1));

        vm.expectRevert(ICaliberMailbox.HubBridgeAdapterAlreadySet.selector);
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(1));

        vm.expectRevert(ICaliberMailbox.HubBridgeAdapterAlreadySet.selector);
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(2));
    }

    function test_RevertWhen_ZeroBridgeAdapterAddress() public {
        vm.expectRevert(ICaliberMailbox.ZeroBridgeAdapterAddress.selector);
        vm.prank(dao);
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(0));
    }

    function test_SetHubBridgeAdapter() public {
        vm.expectRevert(ICaliberMailbox.HubBridgeAdapterNotSet.selector);
        caliberMailbox.getHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3);

        vm.expectEmit(true, true, false, false, address(caliberMailbox));
        emit ICaliberMailbox.HubBridgeAdapterSet(uint256(IBridgeAdapter.Bridge.ACROSS_V3), address(1));
        vm.prank(dao);
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, address(1));

        assertEq(caliberMailbox.getHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3), address(1));
    }
}
