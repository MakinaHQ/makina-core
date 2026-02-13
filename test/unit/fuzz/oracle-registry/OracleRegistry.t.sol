// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract OracleRegistry_Unit_Fuzz_Test is Base_Test {
    MockERC20 internal baseToken;
    MockERC20 internal quoteToken;
    MockPriceFeed internal basePriceFeed1;
    MockPriceFeed internal basePriceFeed2;
    MockPriceFeed internal quotePriceFeed1;
    MockPriceFeed internal quotePriceFeed2;

    uint32 internal price_b_e;
    uint32 internal price_q_e;

    /// b represents the base token
    /// q represents the quote token
    /// e represents the reference currency of the oracle registry
    /// x represents the intermediate token between b and e
    /// y represents the intermediate token between q and e
    struct Data {
        uint8 baseTokenDecimals;
        uint8 quoteTokenDecimals;
        uint8 bf1Decimals;
        uint8 bf2Decimals;
        uint8 qf1Decimals;
        uint8 qf2Decimals;
        uint32 price_b_x;
        uint32 price_x_e;
        uint32 price_q_y;
        uint32 price_y_e;
    }

    function setUp() public override {
        Base_Test.setUp();

        accessManager = _deployAccessManager(deployer, deployer);
        oracleRegistry = _deployOracleRegistry(address(accessManager), address(accessManager));

        _setupOracleRegistryAMFunctionRoles(accessManager, address(oracleRegistry));
        setupAccessManagerRolesAndOwnership();
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.baseTokenDecimals = uint8(bound(data.baseTokenDecimals, 6, 18));
        data.quoteTokenDecimals = uint8(bound(data.quoteTokenDecimals, 6, 18));
        data.bf1Decimals = uint8(bound(data.bf1Decimals, 6, 18));
        data.bf2Decimals = uint8(bound(data.bf2Decimals, 6, 18));
        data.qf1Decimals = uint8(bound(data.qf1Decimals, 6, 18));
        data.qf2Decimals = uint8(bound(data.qf2Decimals, 6, 18));

        data.price_b_x = uint32(bound(data.price_b_x, 1, 1e5));
        data.price_x_e = uint32(bound(data.price_x_e, 1, 1e4));
        data.price_q_y = uint32(bound(data.price_q_y, 1, 1e5));
        data.price_y_e = uint32(bound(data.price_y_e, 1, 1e4));
        price_b_e = data.price_b_x * data.price_x_e;
        price_q_e = data.price_q_y * data.price_y_e;

        baseToken = new MockERC20("Base Token", "BT", data.baseTokenDecimals);
        quoteToken = new MockERC20("Quote Token", "QT", data.quoteTokenDecimals);
    }

    // 2 base feeds and 2 quote feeds
    function testFuzz_GetPrice_1(Data memory data) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(data.price_b_x * (10 ** data.bf1Decimals)), block.timestamp);
        basePriceFeed2 =
            new MockPriceFeed(data.bf2Decimals, int256(data.price_x_e * (10 ** data.bf2Decimals)), block.timestamp);
        quotePriceFeed1 =
            new MockPriceFeed(data.qf1Decimals, int256(data.price_q_y * (10 ** data.qf1Decimals)), block.timestamp);
        quotePriceFeed2 =
            new MockPriceFeed(data.qf2Decimals, int256(data.price_y_e * (10 ** data.qf2Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setFeedRoute(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, (10 ** data.quoteTokenDecimals) * price_b_e / price_q_e);
    }

    // 2 base feeds and 1 quote feed
    function testFuzz_GetPrice_2(Data memory data) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(data.price_b_x * (10 ** data.bf1Decimals)), block.timestamp);
        basePriceFeed2 =
            new MockPriceFeed(data.bf2Decimals, int256(data.price_x_e * (10 ** data.bf2Decimals)), block.timestamp);
        quotePriceFeed1 =
            new MockPriceFeed(data.qf1Decimals, int256(price_q_e * (10 ** data.qf1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken),
            address(basePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(basePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        oracleRegistry.setFeedRoute(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, (10 ** data.quoteTokenDecimals) * price_b_e / price_q_e);
    }

    // 1 base feed and 2 quote feeds
    function testFuzz_GetPrice_3(Data memory data) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(price_b_e * (10 ** data.bf1Decimals)), block.timestamp);
        quotePriceFeed1 =
            new MockPriceFeed(data.qf1Decimals, int256(data.price_q_y * (10 ** data.qf1Decimals)), block.timestamp);
        quotePriceFeed2 =
            new MockPriceFeed(data.qf2Decimals, int256(data.price_y_e * (10 ** data.qf2Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setFeedRoute(
            address(quoteToken),
            address(quotePriceFeed1),
            DEFAULT_PF_STALE_THRSHLD,
            address(quotePriceFeed2),
            DEFAULT_PF_STALE_THRSHLD
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, (10 ** data.quoteTokenDecimals) * price_b_e / price_q_e);
    }

    // 1 base feed and 1 quote feed
    function testFuzz_GetPrice_4(Data memory data) public {
        _fuzzTestSetupAfter(data);

        basePriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(price_b_e * (10 ** data.bf1Decimals)), block.timestamp);
        quotePriceFeed1 =
            new MockPriceFeed(data.qf1Decimals, int256(price_q_e * (10 ** data.qf1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(baseToken), address(basePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setFeedRoute(
            address(quoteToken), address(quotePriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        uint256 price = oracleRegistry.getPrice(address(baseToken), address(quoteToken));
        assertEq(price, (10 ** data.quoteTokenDecimals) * price_b_e / price_q_e);
    }
}
