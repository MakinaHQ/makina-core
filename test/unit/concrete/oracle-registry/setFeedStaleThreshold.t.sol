// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";

import {Base_Test} from "test/BaseTest.sol";

contract SetFeedStaleThreshold_Unit_Concrete_Test is Base_Test {
    MockPriceFeed internal priceFeed1;

    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setFeedStaleThreshold(address(0), 0);
    }

    function test_SetFeedStaleThreshold() public {
        priceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        assertEq(oracleRegistry.feedStaleThreshold(address(priceFeed1)), 0);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        assertEq(oracleRegistry.feedStaleThreshold(address(priceFeed1)), DEFAULT_PF_STALE_THRSHLD);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit IOracleRegistry.FeedStaleThresholdChange(address(priceFeed1), DEFAULT_PF_STALE_THRSHLD, 1 days);
        vm.prank(dao);
        oracleRegistry.setFeedStaleThreshold(address(priceFeed1), 1 days);

        assertEq(oracleRegistry.feedStaleThreshold(address(priceFeed1)), 1 days);
    }
}
