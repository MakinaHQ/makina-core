// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IOracleRegistry} from "../src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract OracleRegistryTest is BaseTest {
    event FeedStaleThresholdChange(address indexed feed, uint256 oldThreshold, uint256 newThreshold);
    event TokenFeedDataRegistered(address indexed token, address indexed feed1, address indexed feed2);

    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;

    MockPriceFeed internal basePriceFeed1;
    MockPriceFeed internal basePriceFeed2;
    MockPriceFeed internal quotePriceFeed1;
    MockPriceFeed internal quotePriceFeed2;

    /// @dev A and B are either base or quote tokens, C and D are intermediate tokens
    /// and E is the reference currency of the oracle registry
    uint256 internal constant PRICE_A_E = 60000;
    uint256 internal constant PRICE_A_C = 24;
    uint256 internal constant PRICE_C_E = 2500;

    uint256 internal constant PRICE_B_E = 600;
    uint256 internal constant PRICE_B_D = 12;
    uint256 internal constant PRICE_D_E = 50;

    uint256 internal constant PRICE_A_B = 100;

    function _setUp() public override {
        baseToken = new MockERC20("Base Token", "BT", 8);
        quoteToken = new MockERC20("Quote Token", "QT", 18);
    }

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

    function test_cannotGetUnitializedTokenFeedData() public {
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        oracleRegistry.getTokenFeedData(address(0));
    }

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
        uint256 startTimestamp = vm.getBlockTimestamp();
        basePriceFeed1 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        quotePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());

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
        uint256 startTimestamp = vm.getBlockTimestamp();
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, startTimestamp);

        skip(DEFAULT_PF_STALE_THRSHLD + 1);

        basePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());

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

        basePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());

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

        basePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());
        quotePriceFeed1 = new MockPriceFeed(18, 1e18, vm.getBlockTimestamp());

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
