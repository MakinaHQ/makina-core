// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Hub_Test} from "../UnitConcrete.t.sol";

contract Getters_MachineFactory_Unit_Concrete_Test is Unit_Concrete_Hub_Test {
    function test_Getters() public view {
        assertEq(machineFactory.registry(), address(hubCoreRegistry));
        assertTrue(machineFactory.isMachine(address(machine)));
        assertTrue(machineFactory.isCaliber(address(caliber)));
        assertFalse(machineFactory.isMachine(address(0)));
        assertFalse(machineFactory.isCaliber(address(0)));
    }
}
