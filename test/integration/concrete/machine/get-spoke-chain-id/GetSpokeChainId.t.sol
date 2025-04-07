// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeChainId_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_indexOutOfRange() public {
        vm.expectRevert();
        machine.getSpokeChainId(0);
    }

    function test_GetSpokeChainId() public {
        vm.prank(dao);
        machine.addSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);

        assertEq(machine.getSpokeChainId(0), SPOKE_CHAIN_ID);

        vm.startPrank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID + 1, WORMHOLE_SPOKE_CHAIN_ID + 1);
        machine.addSpokeCaliber(SPOKE_CHAIN_ID + 1, spokeCaliberMailboxAddr);

        assertEq(machine.getSpokeChainId(0), SPOKE_CHAIN_ID);
        assertEq(machine.getSpokeChainId(1), SPOKE_CHAIN_ID + 1);
    }
}
