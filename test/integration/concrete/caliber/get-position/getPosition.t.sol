// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract GetPosition_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_GetPosition_ReturnsEmptyPositionForUnregisteredID() public view {
        ICaliber.Position memory position = caliber.getPosition(0);
        assertEq(position.lastAccountingTime, 0);
        assertEq(position.value, 0);
    }

    function test_GetPosition_ReturnsOldValuesForUnaccountedPosition() public withTokenAsBT(address(baseToken)) {
        uint256 amount1 = 1e18;

        // deposit in vault
        deal(address(baseToken), address(caliber), amount1, true);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), amount1);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        uint256 oldTimestamp = block.timestamp;

        skip(1 hours);
        deal(address(vault), address(caliber), amount1, true);

        ICaliber.Position memory position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, oldTimestamp);
        assertEq(position.value, PRICE_B_A * amount1);
    }

    function test_GetPosition_ReturnsUpdatedValuesForAccountedPosition() public withTokenAsBT(address(baseToken)) {
        uint256 amount1 = 1e18;
        // deposit in vault
        deal(address(baseToken), address(caliber), amount1, true);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), amount1);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        ICaliber.Position memory position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, block.timestamp);
        assertEq(position.value, PRICE_B_A * amount1);

        // increase position value
        uint256 amount2 = 3e18;
        deal(address(baseToken), address(caliber), amount2, true);
        mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), amount2);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, block.timestamp);
        assertEq(position.value, PRICE_B_A * (amount1 + amount2));

        // increase time
        uint256 oldTimestamp = block.timestamp;
        uint256 newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);

        position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, oldTimestamp);
        assertEq(position.value, PRICE_B_A * (amount1 + amount2));

        // account for position
        caliber.accountForPosition(acctInstruction);

        position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, newTimestamp);
        assertEq(position.value, PRICE_B_A * (amount1 + amount2));

        // decrease position value
        uint256 sharesToRedeem = vault.balanceOf(address(caliber)) / 3;
        uint256 amount3 = vault.previewRedeem(sharesToRedeem);
        mgmtInstruction =
            WeirollUtils._build4626RedeemInstruction(address(caliber), VAULT_POS_ID, address(vault), sharesToRedeem);
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        position = caliber.getPosition(VAULT_POS_ID);
        assertEq(position.lastAccountingTime, newTimestamp);
        assertEq(position.value, PRICE_B_A * (amount1 + amount2 - amount3));
    }
}
