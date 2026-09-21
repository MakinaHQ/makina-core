// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract GetFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_RevertGiven_FeedRouteUnregistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceFeedRouteNotRegistered.selector, address(0)));
        oracleRegistry.getFeedRoute(address(0));
    }

    function test_GetFeedRoute() public {
        MockPriceFeed priceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        MockPriceFeed priceFeed2 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(priceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(priceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        (address feed1, address feed2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(feed1, address(priceFeed1));
        assertEq(feed2, address(priceFeed2));
    }
}
