// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {Machine_Unit_Concrete_Test} from "../Machine.t.sol";

contract IsSpokeCaliberEnabled_Unit_Concrete_Test is Machine_Unit_Concrete_Test {
    function test_RevertWhen_SpokeBridgeAdapterNotSet() public {
        vm.expectRevert(Errors.InvalidChainId.selector);
        machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID);
    }

    function test_IsSpokeCaliberEnabled() public {
        uint16[] memory bridges;
        address[] memory adapters;

        vm.prank(dao);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, bridges, adapters);

        assertTrue(machine.isSpokeCaliberEnabled(SPOKE_CHAIN_ID));
    }
}
