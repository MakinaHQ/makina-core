// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./BaseTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract CaliberFuzzTest is BaseTest {
    event PositionCreated(uint256 indexed id, bool indexed isBaseToken);

    MockERC20 private baseToken;

    MockPriceFeed private b1PriceFeed1;
    MockPriceFeed private aPriceFeed1;

    uint256 private accountingTokenUnit;
    uint256 private baseTokenUnit;

    struct Data {
        uint8 aDecimals;
        uint8 b1Decimals;
        uint8 af1Decimals;
        uint8 af2Decimals;
        uint8 b1f1Decimals;
        uint8 b1f2Decimals;
        uint16 a_e_price; // price of accounting token in oracle registry's reference currency
        uint16 b_e_price; // price of base token in oracle registry's reference currency
    }

    constructor() {
        mode = TestMode.FUZZ;
    }

    function _fuzzTestSetupAfter(Data memory data) public {
        data.aDecimals = uint8(bound(data.aDecimals, 6, 18));
        data.b1Decimals = uint8(bound(data.b1Decimals, 6, 18));
        data.af1Decimals = uint8(bound(data.af1Decimals, 6, 18));
        data.b1f1Decimals = uint8(bound(data.b1f1Decimals, 6, 18));

        data.a_e_price = uint16(bound(data.a_e_price, 1, type(uint16).max));
        data.b_e_price = uint16(bound(data.b_e_price, 1, type(uint16).max));

        accountingToken = new MockERC20("Accounting Token", "ACT", data.aDecimals);
        baseToken = new MockERC20("Base Token", "BT", data.b1Decimals);

        accountingTokenUnit = 10 ** data.aDecimals;
        baseTokenUnit = 10 ** data.b1Decimals;

        accountingTokenPosID = 1;

        aPriceFeed1 =
            new MockPriceFeed(data.af1Decimals, int256(data.a_e_price * (10 ** data.af1Decimals)), block.timestamp);
        b1PriceFeed1 =
            new MockPriceFeed(data.b1f1Decimals, int256(data.b_e_price * (10 ** data.b1f1Decimals)), block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setTokenFeedData(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setTokenFeedData(
            address(baseToken), address(b1PriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        vm.stopPrank();

        caliber = _deployCaliber(address(accountingToken), accountingTokenPosID, bytes32(0));
    }

    function test_accountForATPosition_fuzz(Data memory data) public {
        _fuzzTestSetupAfter(data);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        deal(address(accountingToken), address(caliber), 2 * accountingTokenUnit, true);

        assertEq(caliber.getPosition(1).value, 0);
        assertEq(caliber.getPosition(1).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(1);

        assertEq(value, 2 * accountingTokenUnit);
        assertEq(change, int256(value));
        assertEq(caliber.getPosition(1).value, value);
        assertEq(caliber.getPosition(1).lastAccountingTime, block.timestamp);
    }

    function test_accountForBTPosition_fuzz(Data memory data) public {
        _fuzzTestSetupAfter(data);

        vm.prank(dao);
        caliber.addBaseToken(address(baseToken), 2);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        // set caliber's base tokens balance to 2
        deal(address(baseToken), address(caliber), 2 * baseTokenUnit, true);

        assertEq(caliber.getPosition(2).value, 0);
        assertEq(caliber.getPosition(2).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(2);

        assertEq(value, 2 * (accountingTokenUnit * data.b_e_price / data.a_e_price));
        assertEq(change, int256(value));
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        // set caliber's base tokens balance to 3
        deal(address(baseToken), address(caliber), 3 * baseTokenUnit, true);
        // set caliber's accounting tokens balance to 10 to check there is no effect
        deal(address(accountingToken), address(caliber), 10 * data.aDecimals, true);

        (value, change) = caliber.accountForBaseToken(2);

        assertEq(value, 3 * (accountingTokenUnit * data.b_e_price / data.a_e_price));
        assertEq(change, int256(accountingTokenUnit * data.b_e_price / data.a_e_price));
        assertEq(caliber.getPosition(2).value, value);
        assertEq(caliber.getPosition(2).lastAccountingTime, newTimestamp);
    }
}
