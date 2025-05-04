// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract SetSpokeBridgeAdapter_Unit_Concrete_Test is Machine_Unit_Concrete_Test {
    function setUp() public virtual override {
        Machine_Unit_Concrete_Test.setUp();

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), new uint16[](0), new address[](0));
    }

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(0));
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        vm.prank(dao);
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID + 1, ACROSS_V3_BRIDGE_ID, address(0));
    }

    function test_RevertGiven_SpokeBridgeAdapterAlreadySet() public {
        vm.startPrank(address(dao));

        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(1));

        vm.expectRevert(IMachine.SpokeBridgeAdapterAlreadySet.selector);
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(1));

        vm.expectRevert(IMachine.SpokeBridgeAdapterAlreadySet.selector);
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(2));
    }

    function test_RevertWhen_ZeroBridgeAdapterAddress() public {
        vm.expectRevert(IMachine.ZeroBridgeAdapterAddress.selector);
        vm.prank(dao);
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(0));
    }

    function test_SetSpokeBridgeAdapter() public {
        vm.expectRevert(IMachine.SpokeBridgeAdapterNotSet.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID);

        vm.expectEmit(true, true, true, false, address(machine));
        emit IMachine.SpokeBridgeAdapterSet(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(1));
        vm.prank(dao);
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, address(1));

        assertEq(machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID), address(1));
    }
}
