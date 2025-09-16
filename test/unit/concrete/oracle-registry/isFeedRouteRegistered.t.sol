// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract IsFeedRouteRegistered_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_FalseForUnregisteredToken() public view {
        assertFalse(oracleRegistry.isFeedRouteRegistered(address(0)));
    }
}
