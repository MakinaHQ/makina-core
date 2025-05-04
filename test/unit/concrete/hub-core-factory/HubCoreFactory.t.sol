// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract Getters_HubCoreFactory_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(hubCoreFactory.registry(), address(hubCoreRegistry));
        assertTrue(hubCoreFactory.isMachine(address(machine)));
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));
        assertFalse(hubCoreFactory.isMachine(address(0)));
        assertFalse(hubCoreFactory.isCaliber(address(0)));
    }
}
