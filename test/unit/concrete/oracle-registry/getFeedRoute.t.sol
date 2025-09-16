// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract GetFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_RevertGiven_FeedRouteUnregistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(0)));
        oracleRegistry.getFeedRoute(address(0));
    }
}
