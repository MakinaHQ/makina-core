// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract AddSpokeCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        machine.addSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);
    }

    function test_RevertGiven_EvmChainIdNotRegistered() public {
        vm.prank(dao);
        vm.expectRevert(abi.encodeWithSelector(IChainRegistry.EvmChainIdNotRegistered.selector, SPOKE_CHAIN_ID + 1));
        machine.addSpokeCaliber(SPOKE_CHAIN_ID + 1, spokeCaliberMailboxAddr);
    }

    function test_RevertGiven_CaliberAlreadyExists() public {
        vm.startPrank(dao);

        machine.addSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);

        vm.expectRevert(IMachine.SpokeCaliberAlreadyExists.selector);
        machine.addSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);
    }

    function test_AddSpokeCaliber() public {
        vm.prank(dao);
        vm.expectEmit(true, true, false, false, address(machine));
        emit IMachine.SpokeCaliberAdded(SPOKE_CHAIN_ID);
        machine.addSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr);

        IMachine.SpokeCaliberData memory spokeCaliberData = machine.getSpokeCaliberData(SPOKE_CHAIN_ID);
        assertEq(spokeCaliberData.caliberMailbox, spokeCaliberMailboxAddr);
    }
}
