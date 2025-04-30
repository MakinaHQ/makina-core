// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {MakinaGovernable_Unit_Concrete_Test} from "../makina-governable/MakinaGovernable.t.sol";

import {Unit_Concrete_Spoke_Test} from "../UnitConcrete.t.sol";

contract MakinaGovernable_CaliberMailbox_Unit_Concrete_Test is
    MakinaGovernable_Unit_Concrete_Test,
    Unit_Concrete_Spoke_Test
{
    function setUp() public override(MakinaGovernable_Unit_Concrete_Test, Unit_Concrete_Spoke_Test) {
        Unit_Concrete_Spoke_Test.setUp();
        governable = IMakinaGovernable(address(caliberMailbox));
    }
}
