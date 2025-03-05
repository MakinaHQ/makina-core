// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {Caliber} from "src/caliber/Caliber.sol";

import {Base_Spoke_Test} from "test/base/Base.t.sol";

contract Caliber_Integration_Fuzz_Test is Base_Spoke_Test {
    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    MockPriceFeed private b1PriceFeed1;
    MockPriceFeed private aPriceFeed1;

    Caliber public caliber;

    uint256 private accountingTokenUnit;
    uint256 private baseTokenUnit;

    struct Data {
        uint8 aDecimals;
        uint8 b1Decimals;
        uint8 af1Decimals;
        uint8 bf1Decimals;
        uint16 a_e_price; // price of accounting token in oracle registry's reference currency
        uint16 b_e_price; // price of base token in oracle registry's reference currency
    }

    function setUp() public override {
        Base_Spoke_Test.setUp();
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.aDecimals = uint8(bound(data.aDecimals, 6, 18));
        data.b1Decimals = uint8(bound(data.b1Decimals, 6, 18));
        data.af1Decimals = uint8(bound(data.af1Decimals, 6, 18));
        data.bf1Decimals = uint8(bound(data.bf1Decimals, 6, 18));

        data.a_e_price = uint16(bound(data.a_e_price, 1, type(uint16).max));
        data.b_e_price = uint16(bound(data.b_e_price, 1, type(uint16).max));

        accountingToken = new MockERC20("Accounting Token", "ACT", data.aDecimals);
        baseToken = new MockERC20("Base Token", "BT", data.b1Decimals);

        accountingTokenUnit = 10 ** data.aDecimals;
        baseTokenUnit = 10 ** data.b1Decimals;

        aPriceFeed1 =
            new MockPriceFeed(data.af1Decimals, int256(data.a_e_price * (10 ** data.af1Decimals)), block.timestamp);
        b1PriceFeed1 =
            new MockPriceFeed(data.bf1Decimals, int256(data.b_e_price * (10 ** data.bf1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        (caliber,) =
            _deployCaliber(address(0), address(accountingToken), HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID, bytes32(0));
    }

    function testFuzz_AccountForATPosition(Data memory data, uint256 amount) public {
        _fuzzTestSetupAfter(data);
        amount = bound(amount, 0, 1e30);

        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, 0);

        deal(address(accountingToken), address(caliber), amount, true);

        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(1);

        assertEq(value, amount);
        assertEq(change, int256(value));
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, block.timestamp);
    }

    function testFuzz_AccountForBTPosition(Data memory data, uint256 amount1, uint256 amount2) public {
        _fuzzTestSetupAfter(data);
        amount1 = bound(amount1, 0, 1e20);
        amount2 = bound(amount2, 0, 1e20);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, 0);

        // mint amount1 base tokens to caliber
        deal(address(baseToken), address(caliber), amount1, true);

        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, 0);

        (uint256 value1, int256 change1) = caliber.accountForBaseToken(2);

        assertEq(value1, amount1 * (data.b_e_price * accountingTokenUnit / data.a_e_price) / baseTokenUnit);
        assertEq(change1, int256(value1));
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value1);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        // mint amount2 base tokens to caliber
        deal(address(baseToken), address(caliber), amount2, true);
        // increase caliber's accounting token balance to check that there is no effect
        deal(address(accountingToken), address(caliber), 1000 * accountingTokenUnit, true);

        (uint256 value2, int256 change2) = caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(value2, amount2 * (data.b_e_price * accountingTokenUnit / data.a_e_price) / baseTokenUnit);
        assertEq(change2, int256(value2) - int256(value1));
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value2);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, newTimestamp);
    }
}
