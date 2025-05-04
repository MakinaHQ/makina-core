// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract Getters_CaliberFactory_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_Getters() public view {
        assertEq(caliberFactory.registry(), address(spokeCoreRegistry));
        assertTrue(caliberFactory.isCaliber(address(caliber)));
        assertTrue(caliberFactory.isCaliberMailbox(address(caliberMailbox)));
        assertFalse(caliberFactory.isCaliber(address(0)));
        assertFalse(caliberFactory.isCaliberMailbox(address(0)));
    }
}
