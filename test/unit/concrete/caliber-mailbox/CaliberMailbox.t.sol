// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract CaliberMailbox_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_Getters() public view {
        assertEq(caliberMailbox.caliber(), address(caliber));
    }
}
