// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract SetFeedStaleThreshold_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    MockPriceFeed internal priceFeed1;

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setFeedStaleThreshold(address(0), 0);
    }

    function test_SetFeedStaleThreshold() public {
        baseToken = new MockERC20("Base Token", "BT", 18);
        priceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), 0);

        vm.prank(dao);
        oracleRegistry.setFeedRoute(address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);

        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedStaleThresholdChanged(address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, 1 days);
        vm.prank(dao);
        oracleRegistry.setFeedStaleThreshold(address(priceFeed1), 1 days);

        assertEq(oracleRegistry.getFeedStaleThreshold(address(priceFeed1)), 1 days);
    }
}
