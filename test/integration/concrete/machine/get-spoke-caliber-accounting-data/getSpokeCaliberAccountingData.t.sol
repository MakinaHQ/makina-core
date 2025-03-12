// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeCaliberAccountingData_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_EmptyStructWithHubChainId() public view {
        // hub caliber data not accessible here
        IMachine.SpokeCaliberData memory data = machine.getSpokeCaliberAccountingData(block.chainid);
        assertEq(data.machineMailbox, address(0));
    }

    function test_EmptyStructWithInvalidSpokeChainId() public view {
        // invalid spoke chain data
        IMachine.SpokeCaliberData memory data = machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(data.machineMailbox, address(0));
    }

    function test_GetSpokeCaliberAccountingData() public {
        vm.prank(dao);
        spokeMachineMailboxAddr = machine.createSpokeMailbox(SPOKE_CHAIN_ID);
        IMachine.SpokeCaliberData memory data = machine.getSpokeCaliberAccountingData(SPOKE_CHAIN_ID);
        assertEq(data.machineMailbox, spokeMachineMailboxAddr);
    }
}
