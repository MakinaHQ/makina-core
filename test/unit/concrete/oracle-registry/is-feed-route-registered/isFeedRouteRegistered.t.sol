// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract IsFeedRouteRegistered_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_IsFeedRouteRegistered() public {
        assertFalse(oracleRegistry.isFeedRouteRegistered(address(baseToken)));

        MockPriceFeed priceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        assertTrue(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
    }
}
