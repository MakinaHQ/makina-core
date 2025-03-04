// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract HubDualMailbox_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(hubDualMailbox.machine(), address(machine));
        assertEq(hubDualMailbox.caliber(), address(caliber));
    }
}
