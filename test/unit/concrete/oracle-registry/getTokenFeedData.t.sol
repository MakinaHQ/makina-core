// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {Base_Test} from "test/BaseTest.sol";

contract GetTokenFeedData_Unit_Concrete_Test is Base_Test {
    function test_RevertGiven_TokenFeedDataUnregistered() public {
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getTokenFeedData(address(0));
    }
}
