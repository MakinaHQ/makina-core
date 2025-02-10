// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract GetPosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_GetPosition_ReturnsEmptyPositionForUnregisteredID() public view {
        ICaliber.Position memory position = caliber.getPosition(0);
        assertEq(position.lastAccountingTime, 0);
        assertEq(position.value, 0);
        assertEq(position.isBaseToken, false);
    }

    function test_GetPosition_ReturnsOldValuesForUnaccountedPosition() public {
        deal(address(accountingToken), address(caliber), 1e18, true);

        ICaliber.Position memory position = caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);
        assertEq(position.lastAccountingTime, 0);
        assertEq(position.value, 0);
        assertEq(position.isBaseToken, true);
    }

    function test_GetPosition_ReturnsUpdatedValuesForAccountedPosition() public {
        uint256 newValue = 1e18;
        deal(address(accountingToken), address(caliber), newValue, true);
        caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        ICaliber.Position memory position = caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);
        assertEq(position.lastAccountingTime, block.timestamp);
        assertEq(position.value, newValue);
        assertEq(position.isBaseToken, true);

        // increase position value
        newValue += 1e18;
        deal(address(accountingToken), address(caliber), newValue, true);
        caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        position = caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);
        assertEq(position.lastAccountingTime, block.timestamp);
        assertEq(position.value, newValue);
        assertEq(position.isBaseToken, true);

        // increase time
        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);
        caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        position = caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);
        assertEq(position.lastAccountingTime, newTimestamp);
        assertEq(position.value, newValue);
        assertEq(position.isBaseToken, true);

        // decrease position value
        newValue -= 1e18;
        deal(address(accountingToken), address(caliber), newValue, true);
        caliber.accountForBaseToken(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);

        position = caliber.getPosition(HUB_CALIBER_ACCOUNTING_TOKEN_POS_ID);
        assertEq(position.lastAccountingTime, newTimestamp);
        assertEq(position.value, newValue);
        assertEq(position.isBaseToken, true);
    }
}
