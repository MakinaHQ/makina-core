// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberFuzzTest is BaseTest {
    event PositionAdded(uint256 indexed id, bool indexed isBaseToken);

    MockERC20 private baseToken;

    MockPriceFeed private b1PriceFeed1;
    MockPriceFeed private aPriceFeed1;

    uint256 ACCOUNTING_TOKEN_UNIT;
    uint256 BASE_TOKEN_UNIT;

    /// @dev A is the accounting token, B is the base token
    /// and E is the reference currency of the oracle registry
    uint256 private constant PRICE_A_E = 600;
    uint256 private constant PRICE_B_E = 60000;
    uint256 private constant PRICE_B_A = 100;

    struct Data {
        uint8 aDecimals;
        uint8 b1Decimals;
        uint8 af1Decimals;
        uint8 af2Decimals;
        uint8 b1f1Decimals;
        uint8 b1f2Decimals;
    }

    constructor() {
        mode = TestMode.FUZZ;
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.aDecimals = uint8(bound(data.aDecimals, 6, 18));
        data.b1Decimals = uint8(bound(data.b1Decimals, 6, 18));
        data.af1Decimals = uint8(bound(data.af1Decimals, 6, 18));
        data.b1f1Decimals = uint8(bound(data.b1f1Decimals, 6, 18));

        accountingToken = new MockERC20("Accounting Token", "ACT", data.aDecimals);
        baseToken = new MockERC20("Base Token", "BT", data.b1Decimals);

        ACCOUNTING_TOKEN_UNIT = 10 ** data.aDecimals;
        BASE_TOKEN_UNIT = 10 ** data.b1Decimals;

        accountingTokenPosID = 1;

        aPriceFeed1 = new MockPriceFeed(data.af1Decimals, int256(PRICE_A_E * (10 ** data.af1Decimals)), block.timestamp);
        b1PriceFeed1 =
            new MockPriceFeed(data.b1f1Decimals, int256(PRICE_B_E * (10 ** data.b1f1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        caliber = _deployCaliber(address(accountingToken), accountingTokenPosID);
    }

    function test_accountForATPosition_fuzz(Data memory data) public {
        _fuzzTestSetupAfter(data);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        deal(address(accountingToken), address(caliber), 2 * ACCOUNTING_TOKEN_UNIT, true);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        caliber.accountForBaseToken(1);

        assertEq(caliber.getPosition(1).value, 2 * ACCOUNTING_TOKEN_UNIT);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);
    }

    function test_accountForBTPosition_fuzz(Data memory data) public {
        _fuzzTestSetupAfter(data);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        deal(address(baseToken), address(caliber), 2 * BASE_TOKEN_UNIT, true);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 2 * PRICE_B_A * ACCOUNTING_TOKEN_UNIT);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 3 * BASE_TOKEN_UNIT, true);
        deal(address(accountingToken), address(caliber), 10 * data.aDecimals, true);

        caliber.accountForBaseToken(2);

        assertEq(caliber.getPosition(2).value, 3 * PRICE_B_A * ACCOUNTING_TOKEN_UNIT);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);
    }
}
