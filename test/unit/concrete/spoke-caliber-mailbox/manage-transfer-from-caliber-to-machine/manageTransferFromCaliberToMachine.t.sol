// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract ManageTransferFromCaliberToMachine_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_RevertWhen_CallerNotCaliber() public {
        vm.expectRevert(ICaliberMailbox.NotCaliber.selector);
        spokeCaliberMailbox.manageTransferFromCaliberToMachine(address(accountingToken), 1e18);
    }

    // @TODO
    function test_ManageTransferFromCaliberToMachine() public {
        vm.startPrank(address(caliber));
        spokeCaliberMailbox.manageTransferFromCaliberToMachine(address(accountingToken), 1e18);
        vm.stopPrank();
    }
}
