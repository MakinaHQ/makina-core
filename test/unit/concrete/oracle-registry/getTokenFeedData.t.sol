// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract GetTokenFeedData_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_cannotGetUnitializedTokenFeedData() public {
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getTokenFeedData(address(0));
    }
}
