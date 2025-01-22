// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {HubDualMailbox_Unit_Concrete_Test} from "../HubDualMailbox.t.sol";

contract NotifyAccountingSlim_Unit_Concrete_Test is HubDualMailbox_Unit_Concrete_Test {
    function test_cannotNotifyAccountingSlimWithoutCaliber() public {
        vm.expectRevert(ICaliberMailbox.NotCaliber.selector);
        hubDualMailbox.notifyAccountingSlim(0);
    }

    function test_notifyAccountingSlim() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        vm.prank(address(caliber));
        hubDualMailbox.notifyAccountingSlim(inputAmount);

        assertEq(hubDualMailbox.lastReportedAum(), inputAmount);
        assertEq(hubDualMailbox.lastReportedAumTime(), block.timestamp);
    }
}
