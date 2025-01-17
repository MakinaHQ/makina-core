// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {OracleRegistry_Unit_Concrete_Test} from "./OracleRegistry.t.sol";

contract GetPrice_Unit_Concrete_Test is OracleRegistry_Unit_Concrete_Test {
    function test_cannotGetPriceWithUnitializedQuoteTokenFeedData() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithUnitializedBaseTokenFeedData() public {
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));

        vm.prank(dao);
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );

        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithNegativePrice_1() public {
        basePriceFeed1 = new MockPriceFeed(18, -1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.NegativeTokenPrice.selector, address(basePriceFeed1)));
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithNegativePrice_2() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, -1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.NegativeTokenPrice.selector, address(quotePriceFeed1)));
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithNegativePrice_3() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, -1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.NegativeTokenPrice.selector, address(basePriceFeed2)));
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithNegativePrice_4() public {
        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        quotePriceFeed2 = new MockPriceFeed(18, -1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IOracleRegistry.NegativeTokenPrice.selector, address(quotePriceFeed2)));
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithStalePrice_1() public {
        uint256 startTimestamp = block.timestamp;
        basePriceFeed1 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedStale.selector, address(basePriceFeed1), startTimestamp)
        );
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithStalePrice_2() public {
        uint256 startTimestamp = block.timestamp;
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedStale.selector, address(quotePriceFeed1), startTimestamp)
        );
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithStalePrice_3() public {
        uint256 startTimestamp = vm.getBlockNumber();
        basePriceFeed2 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedStale.selector, address(basePriceFeed2), startTimestamp)
        );
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_cannotGetPriceWithStalePrice_4() public {
        uint256 startTimestamp = vm.getBlockNumber();
        quotePriceFeed2 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        basePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedStale.selector, address(quotePriceFeed2), startTimestamp)
        );
        oracleRegistry.getPrice(address(baseToken), address(quoteToken));
    }

    function test_getPrice_A_B() public {
        basePriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_C * (10 ** 18)), block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, int256(PRICE_C_E * (10 ** 18)), block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_D * (10 ** 18)), block.timestamp);
        quotePriceFeed2 = new MockPriceFeed(18, int256(PRICE_D_E * (10 ** 18)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, PRICE_A_B * (10 ** 18));
    }

    function test_getPrice_B_A() public {
        baseToken = new MockERC20("Base Token", "BT", 18);
        quoteToken = new MockERC20("Quote Token", "QT", 8);

        basePriceFeed1 = new MockPriceFeed(18, int256(PRICE_B_D * (10 ** 18)), block.timestamp);
        basePriceFeed2 = new MockPriceFeed(18, int256(PRICE_D_E * (10 ** 18)), block.timestamp);
        quotePriceFeed1 = new MockPriceFeed(18, int256(PRICE_A_C * (10 ** 18)), block.timestamp);
        quotePriceFeed2 = new MockPriceFeed(18, int256(PRICE_C_E * (10 ** 18)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setTokenFeedData(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, (10 ** 8) / PRICE_A_B);
    }
}
