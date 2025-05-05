// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeCaliberDetailedAum_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_ProvidedChainIdIsHubChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.getSpokeCaliberDetailedAum(block.chainid);
    }

    function test_RevertWhen_ProvidedChainIdIsUnregisteredSpokeChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.getSpokeCaliberDetailedAum(SPOKE_CHAIN_ID);
    }

    function test_GetSpokeCaliberDetailedAum() public withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr) {
        // does not revert
        machine.getSpokeCaliberDetailedAum(SPOKE_CHAIN_ID);
    }
}
