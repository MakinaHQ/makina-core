// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract GetFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_RevertGiven_FeedRouteUnregistered() public {
        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(0)));
        oracleRegistry.getFeedRoute(address(0));
    }
}
