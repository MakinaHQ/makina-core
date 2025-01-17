// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract SetTokenFeedData_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_cannotSetFeedDataWithoutRoleWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setTokenFeedData(address(0), address(0), 0, address(0), 0);
    }

    function test_cannotSetFeedDataWithZeroFeed1() public {
        basePriceFeed2 = new MockPriceFeed(18, int256(PRICE_A_E * (10 ** 18)), block.timestamp);

        vm.expectRevert(IOracleRegistry.InvalidFeedData.selector);
        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(0), DEFAULT_PF_STALE_THRSHLD, address(basePriceFeed2), DEFAULT_PF_STALE_THRSHLD
        );
    }

    function test_setTokenFeedData() public {
        basePriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_C * 10 ** 18), block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, int256(PRICE_C_E * 10 ** 18), block.timestamp);

        vm.expectEmit(true, true, true, true, address(oracleRegistry));
        emit TokenFeedDataRegistered(address(baseToken), address(basePriceFeed1), address(basePriceFeed2));
        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );

        (address tfdFeed1, address tfdFeed2) = oracleRegistry.getTokenFeedData(address(baseToken));
        assertEq(tfdFeed1, address(basePriceFeed1));
        assertEq(tfdFeed2, address(basePriceFeed2));
    }
}
