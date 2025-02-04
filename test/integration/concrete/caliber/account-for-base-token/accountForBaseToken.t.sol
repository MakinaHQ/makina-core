// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract AccountForBaseToken_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertGiven_UnexistingBTPosition() public {
        vm.prank(dao);

        vm.expectRevert(ICaliber.NotBaseTokenPosition.selector);
        caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);
    }

    function test_AccountForATPosition() public {
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        assertEq(value, 0);
        assertEq(change, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, block.timestamp);

        deal(address(accountingToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, block.timestamp);

        (value, change) = caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        assertEq(value, 1e18);
        assertEq(change, 1e18);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID).lastAccountingTime, block.timestamp);
    }

    function test_AccountForBTPosition() public withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID) {
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, 0);

        (uint256 value, int256 change) = caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(value, 0);
        assertEq(change, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, block.timestamp);

        deal(address(baseToken), address(caliber), 1e18, true);

        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, 0);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, block.timestamp);

        (value, change) = caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(value, 1e18 * PRICE_B_A);
        assertEq(change, int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, block.timestamp);

        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 3e18, true);
        // this should not affect the accounting
        deal(address(accountingToken), address(caliber), 10e18, true);

        (value, change) = caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(value, 3e18 * PRICE_B_A);
        assertEq(change, int256(2e18 * PRICE_B_A));
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, newTimestamp);

        newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        deal(address(baseToken), address(caliber), 2e18, true);

        (value, change) = caliber.accountForBaseToken(HUB_CALIBER_BASE_TOKEN_1_POS_ID);

        assertEq(value, 2e18 * PRICE_B_A);
        assertEq(change, -1 * int256(1e18 * PRICE_B_A));
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).value, value);
        assertEq(caliber.getPosition(HUB_CALIBER_BASE_TOKEN_1_POS_ID).lastAccountingTime, newTimestamp);
    }
}
