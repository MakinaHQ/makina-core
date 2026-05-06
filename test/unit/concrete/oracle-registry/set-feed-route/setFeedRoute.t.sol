// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC20NoDecimals} from "test/mocks/MockERC20NoDecimals.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "../OracleRegistry.t.sol";

contract SetFeedRoute_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    MockPriceFeed internal priceFeed1;
    MockPriceFeed internal priceFeed2;
    MockPriceFeed internal priceFeed3;
    MockPriceFeed internal priceFeed4;

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setFeedRoute(address(0), address(0), 0, address(0), 0);
    }

    function test_RevertWhen_ProvidedFeed1Null() public {
        priceFeed2 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectRevert(Errors.InvalidFeedRoute.selector);
        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken), address(0), DEFAULT_PF_STALE_THRSHLD, address(priceFeed2), DEFAULT_PF_STALE_THRSHLD
        );
    }

    function test_RevertWhen_TokenWithoutDecimals() public {
        MockERC20NoDecimals token = new MockERC20NoDecimals("Token", "TKN");
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectRevert(Errors.InvalidDecimals.selector);
        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(token), address(priceFeed1), 0, address(0), 0);
    }

    function test_RevertWhen_TokenDecimalsTooLow() public {
        MockERC20 token = new MockERC20("Token", "TKN", 5);
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectRevert(Errors.InvalidDecimals.selector);
        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(token), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
    }

    function test_RevertWhen_TokenDecimalsTooHigh() public {
        MockERC20 token = new MockERC20("Token", "TKN", 19);
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectRevert(Errors.InvalidDecimals.selector);
        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(token), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
    }

    function test_SetFeedRoute_With1Feed() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteRegistered(address(baseToken), address(priceFeed1), address(priceFeed2));
        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        assertTrue(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
        (address rf1, address rf2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(rf1, address(priceFeed1));
        assertEq(rf2, address(0));
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed2)), 0);
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

        assertTrue(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
        (address rf1, address rf2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(rf1, address(priceFeed1));
        assertEq(rf2, address(priceFeed2));
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed2)), DEFAULT_PF_STALE_THRSHLD);
    }

    function test_SetFeedRoute_ReuseFeed() public {
        priceFeed1 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        priceFeed2 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        priceFeed3 = new MockPriceFeed(18, int256(1e18), block.timestamp);
        priceFeed4 = new MockPriceFeed(18, int256(1e18), block.timestamp);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(priceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(priceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedRouteRegistered(address(quoteToken), address(priceFeed1), address(priceFeed2));
        vm.prank(dao);
        oracleRegistry.setFeedRoute(
            address(quoteToken),
            address(priceFeed1),
            DEFAULT_PF_STALE_THRSHLD + 1,
            address(priceFeed2),
            DEFAULT_PF_STALE_THRSHLD + 1
        );

        assertTrue(oracleRegistry.isFeedRouteRegistered(address(baseToken)));
        (address rf1, address rf2) = oracleRegistry.getFeedRoute(address(baseToken));
        assertEq(rf1, address(priceFeed1));
        assertEq(rf2, address(priceFeed2));

        (rf1, rf2) = oracleRegistry.getFeedRoute(address(quoteToken));
        assertEq(rf1, address(priceFeed1));
        assertEq(rf2, address(priceFeed2));

        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD + 1);
        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed2)), DEFAULT_PF_STALE_THRSHLD + 1);
    }
}
