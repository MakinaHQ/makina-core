// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeBridgeAdapter_Integration_Concrete_Test is Machine_Unit_Concrete_Test {
    IBridgeAdapter.Bridge[] public bridges;
    address[] public spokeBridgeAdapters;

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3);
    }

    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, spokeBridgeAdapters);

        vm.expectRevert(IMachine.SpokeBridgeAdapterNotSet.selector);
        machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3);
    }

    function test_GetSpokeBridgeAdapter() public {
        bridges = new IBridgeAdapter.Bridge[](1);
        bridges[0] = IBridgeAdapter.Bridge.ACROSS_V3;

        spokeBridgeAdapters = new address[](1);
        spokeBridgeAdapters[0] = spokeBridgeAdapterAddr;

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, spokeBridgeAdapters);

        assertEq(spokeBridgeAdapterAddr, machine.getSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3));
    }
}
