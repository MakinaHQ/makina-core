// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/BaseTest.sol";

contract GetPrice_Unit_Concrete_Test is Base_Test {
    /// @dev A and B are either base or quote tokens, C and D are intermediate tokens
    /// and E is the reference currency of the oracle registry
    uint256 internal constant PRICE_A_E = 150;
    uint256 internal constant PRICE_A_C = 50;
    uint256 internal constant PRICE_C_E = 3;

    uint256 internal constant PRICE_B_E = 60000;
    uint256 internal constant PRICE_B_D = 24;
    uint256 internal constant PRICE_D_E = 2500;

    uint256 internal constant PRICE_B_A = 400;

    MockERC20 internal quoteToken;

    MockPriceFeed internal basePriceFeed1;
    MockPriceFeed internal basePriceFeed2;
    MockPriceFeed internal quotePriceFeed1;
    MockPriceFeed internal quotePriceFeed2;

    function setUp() public override {
        Base_Test.setUp();
        baseToken = new MockERC20("Base Token", "BT", 18);
        quoteToken = new MockERC20("Quote Token", "QT", 8);
    }

    function test_RevertGiven_QuoteTokenFeedDataUnitialized() public {
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

    function test_RevertGiven_BaseTokenFeedDataUnitialized() public {
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

    function test_RevertGiven_NegativePrice_1() public {
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

    function test_RevertGiven_NegativePrice_2() public {
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

    function test_RevertGiven_NegativePrice_3() public {
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

    function test_RevertGiven_NegativePrice_4() public {
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

    function test_RevertGiven_StalePrice_1() public {
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

    function test_RevertGiven_StalePrice_2() public {
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

    function test_RevertGiven_StalePrice_3() public {
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

    function test_RevertGiven_StalePrice_4() public {
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

    function test_GetPrice_A_B() public {
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
        assertEq(price, (10 ** 8) / PRICE_B_A);
    }

    function test_GetPrice_B_A() public {
        baseToken = new MockERC20("Base Token", "BT", 8);
        quoteToken = new MockERC20("Quote Token", "QT", 18);

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
        assertEq(price, PRICE_B_A * (10 ** 18));
    }
}
