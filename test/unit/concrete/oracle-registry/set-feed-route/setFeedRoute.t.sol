// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract SetFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    MockPriceFeed internal priceFeed1;
    MockPriceFeed internal priceFeed2;

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setFeedRoute(address(0), address(0), 0, address(0), 0);
    }

    function test_RevertWhen_ProvidedFeed1Null() public {
        priceFeed2 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectRevert(IOracleRegistry.InvalidFeedRoute.selector);
        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken), address(0), DEFAULT_PF_STALE_THRSHLD, address(priceFeed2), DEFAULT_PF_STALE_THRSHLD
        );
    }

    function test_SetFeedRoute_With1Feed() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteRegistered(address(baseToken), address(priceFeed1), address(priceFeed2));
        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        (address tfdFeed1, address tfdFeed2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(tfdFeed1, address(priceFeed1));
        assertEq(tfdFeed2, address(0));
    }

    function test_SetFeedRoute_With2Feeds() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        priceFeed2 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteRegistered(address(baseToken), address(priceFeed1), address(priceFeed2));
        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(priceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(priceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        (address tfdFeed1, address tfdFeed2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(tfdFeed1, address(priceFeed1));
        assertEq(tfdFeed2, address(priceFeed2));
    }
}
