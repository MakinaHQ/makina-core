// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract SetTokenFeedStaleThreshold_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_cannotSetFeedStaleThresholdWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setFeedStaleThreshold(address(0), 0);
    }

    function test_setFeedStaleThreshold() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        assertEq(oracleRegistry.feedStaleThreshold(address(basePriceFeed1)), 0);

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        assertEq(oracleRegistry.feedStaleThreshold(address(basePriceFeed1)), DEFAULT_PF_STALE_THRSHLD);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit FeedStaleThresholdChange(address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, 1 days);
        vm.prank(dao);
        oracleRegistry.setFeedStaleThreshold(address(basePriceFeed1), 1 days);

        assertEq(oracleRegistry.feedStaleThreshold(address(basePriceFeed1)), 1 days);
    }
}
