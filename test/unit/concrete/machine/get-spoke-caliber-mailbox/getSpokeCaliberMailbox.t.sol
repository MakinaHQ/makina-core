// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeCaliberMailbox_Integration_Concrete_Test is Machine_Unit_Concrete_Test {
    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.expectRevert(IMachine.InvalidChainId.selector);
        machine.getSpokeCaliberMailbox(SPOKE_CHAIN_ID);
    }

    function test_GetSpokeCaliberMailbox() public {
        IBridgeAdapter.Bridge[] memory bridges;
        address[] memory adapters;

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, adapters);

        assertEq(spokeCaliberMailboxAddr, machine.getSpokeCaliberMailbox(SPOKE_CHAIN_ID));
    }
}
