// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract Getters_SpokeCoreFactory_Unit_Concrete_Test is Unit_Concrete_Spoke_Test {
    function test_Getters() public view {
        assertEq(spokeCoreFactory.registry(), address(spokeCoreRegistry));
        assertTrue(spokeCoreFactory.isCaliber(address(caliber)));
        assertTrue(spokeCoreFactory.isCaliberMailbox(address(caliberMailbox)));
        assertFalse(spokeCoreFactory.isCaliber(address(0)));
        assertFalse(spokeCoreFactory.isCaliberMailbox(address(0)));
    }
}
