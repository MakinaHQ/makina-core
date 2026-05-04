// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract GetSpokeCaliberNetAum_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_ProvidedChainIdIsHubChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.getSpokeCaliberNetAum(block.chainid);
    }

    function test_RevertWhen_ProvidedChainIdIsUnregisteredSpokeChainId() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
    }

    function test_GetSpokeCaliberNetAum() public withSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr) {
        // does not revert
        machine.getSpokeCaliberNetAum(SPOKE_CHAIN_ID);
    }
}
