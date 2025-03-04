// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Unit_Concrete_Test} from "../UnitConcrete.t.sol";

contract Swapper_Unit_Concrete_Test is Unit_Concrete_Test {
    function setUp() public virtual override {
        Unit_Concrete_Test.setUp();
        _accessManagerTestSetup();
    }
}
