// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./OracleRegistry.t.sol";

contract OracleRegistryFuzzTest is BaseTest {
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

    struct Data {
        uint8 baseTokenDecimals;
        uint8 quoteTokenDecimals;
        uint8 bf1Decimals;
        uint8 bf2Decimals;
        uint8 qf1Decimals;
        uint8 qf2Decimals;
    }

    constructor() {
        mode = TestMode.FUZZ;
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.baseTokenDecimals = uint8(bound(data.baseTokenDecimals, 6, 18));
        data.quoteTokenDecimals = uint8(bound(data.quoteTokenDecimals, 6, 18));
        data.bf1Decimals = uint8(bound(data.bf1Decimals, 6, 18));
        data.bf2Decimals = uint8(bound(data.bf2Decimals, 6, 18));
        data.qf1Decimals = uint8(bound(data.qf1Decimals, 6, 18));
        data.qf2Decimals = uint8(bound(data.qf2Decimals, 6, 18));

        baseToken = new MockERC20("Base Token", "BT", data.baseTokenDecimals);
        quoteToken = new MockERC20("Quote Token", "QT", data.quoteTokenDecimals);
    }

    // 2 base feeds and 2 quote feeds
    function test_getPrice_1_fuzz(Data memory data, bool direction) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 = new MockPriceFeed(
            data.bf1Decimals, int256((direction ? PRICE_A_C : PRICE_B_D) * (10 ** data.bf1Decimals)), block.timestamp
        );
        basePriceFeed2 = new MockPriceFeed(
            data.bf2Decimals, int256((direction ? PRICE_C_E : PRICE_D_E) * (10 ** data.bf2Decimals)), block.timestamp
        );
        quotePriceFeed1 = new MockPriceFeed(
            data.qf1Decimals, int256((direction ? PRICE_B_D : PRICE_A_C) * (10 ** data.qf1Decimals)), block.timestamp
        );
        quotePriceFeed2 = new MockPriceFeed(
            data.qf2Decimals, int256((direction ? PRICE_D_E : PRICE_C_E) * (10 ** data.qf2Decimals)), block.timestamp
        );

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(baseToken), address(basePriceFeed1), address(basePriceFeed2));
        oracleRegistry.setTokenFeedData(address(quoteToken), address(quotePriceFeed1), address(quotePriceFeed2));
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(
            price, direction ? PRICE_A_B * (10 ** data.quoteTokenDecimals) : (10 ** data.quoteTokenDecimals) / PRICE_A_B
        );
    }

    // 2 base feeds and 1 quote feed
    function test_getPrice_2_fuzz(Data memory data, bool direction) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 = new MockPriceFeed(
            data.bf1Decimals, int256((direction ? PRICE_A_C : PRICE_B_D) * (10 ** data.bf1Decimals)), block.timestamp
        );
        basePriceFeed2 = new MockPriceFeed(
            data.bf2Decimals, int256((direction ? PRICE_C_E : PRICE_D_E) * (10 ** data.bf2Decimals)), block.timestamp
        );
        quotePriceFeed1 = new MockPriceFeed(
            data.qf1Decimals, int256((direction ? PRICE_B_E : PRICE_A_E) * (10 ** data.qf1Decimals)), block.timestamp
        );

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(baseToken), address(basePriceFeed1), address(basePriceFeed2));
        oracleRegistry.setTokenFeedData(address(quoteToken), address(quotePriceFeed1), address(0));
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(
            price, direction ? PRICE_A_B * (10 ** data.quoteTokenDecimals) : (10 ** data.quoteTokenDecimals) / PRICE_A_B
        );
    }

    // 1 base feed and 2 quote feeds
    function test_getPrice_3_fuzz(Data memory data, bool direction) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 = new MockPriceFeed(
            data.bf1Decimals, int256((direction ? PRICE_A_E : PRICE_B_E) * (10 ** data.bf1Decimals)), block.timestamp
        );
        quotePriceFeed1 = new MockPriceFeed(
            data.qf1Decimals, int256((direction ? PRICE_B_D : PRICE_A_C) * (10 ** data.qf1Decimals)), block.timestamp
        );
        quotePriceFeed2 = new MockPriceFeed(
            data.qf2Decimals, int256((direction ? PRICE_D_E : PRICE_C_E) * (10 ** data.qf2Decimals)), block.timestamp
        );

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(baseToken), address(basePriceFeed1), address(0));
        oracleRegistry.setTokenFeedData(address(quoteToken), address(quotePriceFeed1), address(quotePriceFeed2));
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(
            price, direction ? PRICE_A_B * (10 ** data.quoteTokenDecimals) : (10 ** data.quoteTokenDecimals) / PRICE_A_B
        );
    }

    // 1 base feed and 1 quote feed
    function test_getPrice_4_fuzz(Data memory data, bool direction) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 = new MockPriceFeed(
            data.bf1Decimals, int256((direction ? PRICE_A_E : PRICE_B_E) * (10 ** data.bf1Decimals)), block.timestamp
        );
        quotePriceFeed1 = new MockPriceFeed(
            data.qf1Decimals, int256((direction ? PRICE_B_E : PRICE_A_E) * (10 ** data.qf1Decimals)), block.timestamp
        );

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(address(baseToken), address(basePriceFeed1), address(0));
        oracleRegistry.setTokenFeedData(address(quoteToken), address(quotePriceFeed1), address(0));
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(
            price, direction ? PRICE_A_B * (10 ** data.quoteTokenDecimals) : (10 ** data.quoteTokenDecimals) / PRICE_A_B
        );
    }
}
