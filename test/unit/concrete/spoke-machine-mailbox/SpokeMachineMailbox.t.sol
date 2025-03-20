// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SpokeMachineMailbox} from "src/mailbox/SpokeMachineMailbox.sol";

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract SpokeMachineMailbox_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    SpokeMachineMailbox public spokeMachineMailbox;

    function setUp() public override {
        super.setUp();
        vm.startPrank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID, WORMHOLE_SPOKE_CHAIN_ID);
        spokeMachineMailbox = SpokeMachineMailbox(machine.createSpokeMailbox(SPOKE_CHAIN_ID));
        vm.stopPrank();
    }
}
