// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract SetSpokeCaliber_Unit_Concrete_Test is Machine_Unit_Concrete_Test {
    uint16[] public bridges;
    address[] public spokeBridgeAdapters;

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.setSpokeCaliber(0, address(0), bridges, spokeBridgeAdapters);
    }

    function test_RevertWhen_EvmChainIdNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.EvmChainIdNotRegistered.selector, SPOKE_CHAIN_ID + 1));
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID + 1, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);
    }

    function test_RevertGiven_SpokeCaliberAlreadySet() public {
        vm.startPrank(address(dao));

        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);

        vm.expectRevert(IMachine.SpokeCaliberAlreadySet.selector);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);

        vm.expectRevert(IMachine.SpokeCaliberAlreadySet.selector);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, makeAddr("spokeCaliberMailbox2"), bridges, spokeBridgeAdapters);
    }

    function test_RevertWhen_MismatchedLength() public {
        bridges = new uint16[](1);

        vm.expectRevert(IMachine.MismatchedLength.selector);
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);
    }

    function test_RevertWhen_SpokeBridgeAdapterAlreadySet() public {
        bridges = new uint16[](2);
        bridges[0] = ACROSS_V3_BRIDGE_ID;
        bridges[1] = ACROSS_V3_BRIDGE_ID;

        spokeBridgeAdapters = new address[](2);
        spokeBridgeAdapters[0] = spokeBridgeAdapterAddr;
        spokeBridgeAdapters[1] = spokeBridgeAdapterAddr;

        vm.expectRevert(IMachine.SpokeBridgeAdapterAlreadySet.selector);
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);

        spokeBridgeAdapters[1] = makeAddr("spokeBridgeAdapter2");

        vm.expectRevert(IMachine.SpokeBridgeAdapterAlreadySet.selector);
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);
    }

    function test_RevertWhen_ZeroBridgeAdapterAddress() public {
        bridges = new uint16[](1);
        bridges[0] = ACROSS_V3_BRIDGE_ID;

        spokeBridgeAdapters = new address[](1);
        spokeBridgeAdapters[0] = address(0);

        vm.expectRevert(IMachine.ZeroBridgeAdapterAddress.selector);
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, address(spokeCaliberMailboxAddr), bridges, spokeBridgeAdapters);
    }

    function test_SetSpokeCaliber() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeCaliberMailbox(SPOKE_CHAIN_ID);

        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID);

        bridges = new uint16[](1);
        bridges[0] = ACROSS_V3_BRIDGE_ID;

        spokeBridgeAdapters = new address[](1);
        spokeBridgeAdapters[0] = spokeBridgeAdapterAddr;

        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.SpokeCaliberMailboxSet(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);

        vm.expectEmit(true, true, true, false, address(machine));
        emit IMachine.SpokeBridgeAdapterSet(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, spokeBridgeAdapters);

        assertEq(machine.getSpokeCaliberMailbox(SPOKE_CHAIN_ID), spokeCaliberMailboxAddr);
        assertEq(machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID), spokeBridgeAdapterAddr);
    }
}
