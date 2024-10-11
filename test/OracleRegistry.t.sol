// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseTest} from "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";

contract OracleRegistryTest is BaseTest {
    event PriceFeedSet(address indexed inputToken, address indexed quoteToken, address priceFeed);

    address private inputToken;
    address private quoteToken;
    address priceFeed;

    function _setUp() public override {
        inputToken = makeAddr("InputToken");
        quoteToken = makeAddr("QuoteToken");
        priceFeed = makeAddr("PriceFeed");
    }

    function test_cannotSetPriceFeedWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        oracleRegistry.setPriceFeed(address(0), address(0), address(0));
    }

    function test_setPriceFeed() public {
        vm.expectEmit(true, true, false, true, address(oracleRegistry));
        emit PriceFeedSet(inputToken, quoteToken, priceFeed);
        vm.prank(dao);
        oracleRegistry.setPriceFeed(inputToken, quoteToken, priceFeed);

        assertEq(oracleRegistry.getPriceFeed(inputToken, quoteToken), priceFeed);
    }

    function test_cannotGetPriceFeedIfNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.PriceFeedNotSet.selector, address(0), address(0)));
        oracleRegistry.getPriceFeed(address(0), address(0));

        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.PriceFeedNotSet.selector, inputToken, quoteToken));
        oracleRegistry.getPriceFeed(inputToken, quoteToken);
    }
}
