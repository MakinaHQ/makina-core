// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract GetHubBridgeAdapter_Integration_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_RevertWhen_HubBridgeAdapterNotSet() public {
        vm.expectRevert(ICaliberMailbox.HubBridgeAdapterNotSet.selector);
        caliberMailbox.getHubBridgeAdapter(ACROSS_V3_BRIDGE_ID);
    }

    function test_GetSpokeBridgeAdapter() public {
        vm.prank(dao);
        caliberMailbox.setHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, address(1));

        assertEq(address(1), caliberMailbox.getHubBridgeAdapter(ACROSS_V3_BRIDGE_ID));
    }
}
