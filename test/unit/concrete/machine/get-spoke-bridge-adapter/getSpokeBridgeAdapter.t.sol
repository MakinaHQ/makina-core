// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeBridgeAdapter_Integration_Concrete_Test is Machine_Unit_Concrete_Test {
    uint16[] public bridges;
    address[] public spokeBridgeAdapters;

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID);
    }

    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, spokeBridgeAdapters);

        vm.expectRevert(Errors.SpokeBridgeAdapterNotSet.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID);
    }

    function test_GetSpokeBridgeAdapter() public {
        bridges = new uint16[](1);
        bridges[0] = ACROSS_V3_BRIDGE_ID;

        spokeBridgeAdapters = new address[](1);
        spokeBridgeAdapters[0] = spokeBridgeAdapterAddr;

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, spokeBridgeAdapters);

        assertEq(spokeBridgeAdapterAddr, machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID));
    }
}
