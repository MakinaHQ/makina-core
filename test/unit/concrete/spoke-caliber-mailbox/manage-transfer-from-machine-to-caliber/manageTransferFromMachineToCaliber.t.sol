// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Spoke_Test} from "../../UnitConcrete.t.sol";

contract ManageTransferFromMachineToCaliber_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    // @TODO
    function test_ManageTransferFromMachineToCaliber() public {
        spokeCaliberMailbox.manageTransferFromMachineToCaliber(address(accountingToken), 1e18);
    }
}
