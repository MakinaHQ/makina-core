// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract GetSpokeCaliberAccountingData_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
    }

    function test_RevertGiven_PositionStale() public withTokenAsBT(address(baseToken)) {
        // create a vault position
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(caliber), inputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        skip(DEFAULT_CALIBER_POS_STALE_THRESHOLD - 1);

        caliberMailbox.getSpokeCaliberAccountingData();

        skip(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.PositionAccountingStale.selector, VAULT_POS_ID));
        caliberMailbox.getSpokeCaliberAccountingData();
    }

    function test_GetSpokeCaliberAccountingData() public withTokenAsBT(address(baseToken)) {
        uint256 aInputAmount = 3e18;
        uint256 bInputAmount = 5e18;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), aInputAmount, true);

        // create vault position
        deal(address(baseToken), address(caliber), bInputAmount, true);
        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), bInputAmount);
        ICaliber.Instruction memory acctInstruction =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        // check accounting token position is correctly accounted for in AUM
        ICaliberMailbox.SpokeCaliberAccountingData memory data = caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, aInputAmount + PRICE_B_A * bInputAmount);
        assertEq(data.bridgesIn.length, 0);
        assertEq(data.bridgesOut.length, 0);
        assertEq(data.positions.length, 1);
        assertEq(data.baseTokens.length, 2);
        _checkEncodedCaliberPosValue(data.positions[0], VAULT_POS_ID, PRICE_B_A * bInputAmount, false);
        _checkEncodedCaliberBTValue(data.baseTokens[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(data.baseTokens[1], address(baseToken), 0);

        skip(1 hours);

        caliber.accountForPosition(acctInstruction);

        // check data is the same after a day
        data = caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(data.netAum, aInputAmount + PRICE_B_A * bInputAmount);
        assertEq(data.bridgesIn.length, 0);
        assertEq(data.bridgesOut.length, 0);
        assertEq(data.positions.length, 1);
        assertEq(data.baseTokens.length, 2);
        _checkEncodedCaliberPosValue(data.positions[0], VAULT_POS_ID, PRICE_B_A * bInputAmount, false);
        _checkEncodedCaliberBTValue(data.baseTokens[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(data.baseTokens[1], address(baseToken), 0);
    }
}
