// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract GetDetailedAum_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
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

        caliber.getDetailedAum();

        skip(1);

        vm.expectRevert(abi.encodeWithSelector(Errors.PositionAccountingStale.selector, VAULT_POS_ID));
        caliber.getDetailedAum();
    }

    function test_RevertWhen_ReentrantCall() public withTokenAsBT(address(baseToken)) {
        uint256 supplyInputAmount = 1e18;
        deal(address(baseToken), address(caliber), supplyInputAmount, true);
        ICaliber.Instruction memory supplyMgmtInstruction = WeirollUtils._buildMockSupplyModuleSupplyInstruction(
            SUPPLY_POS_ID, address(supplyModule), supplyInputAmount
        );
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        baseToken.scheduleReenter(MockERC20.Type.Before, address(caliber), abi.encodeCall(ICaliber.getDetailedAum, ()));

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);
    }

    function test_GetDetailedAum_WithZeroAum() public view {
        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 0);
        assertEq(baseTokensValues.length, 1);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
    }

    function test_GetDetailedAum_UnregisteredToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 0);
        assertEq(baseTokensValues.length, 1);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
    }

    function test_GetDetailedAum_AccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, inputAmount);
        assertEq(positionsValues.length, 0);
        assertEq(baseTokensValues.length, 1);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), inputAmount);
    }

    function test_GetDetailedAum_BaseToken() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount);

        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, inputAmount * PRICE_B_A);
        assertEq(positionsValues.length, 0);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), inputAmount * PRICE_B_A);
    }

    function test_GetDetailedAum_NonDebtPosition() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, inputAmount * PRICE_B_A);
        assertEq(positionsValues.length, 1);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], SUPPLY_POS_ID, inputAmount * PRICE_B_A, false);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), 0);
    }

    function test_GetDetailedAum_DebtPosition() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction memory mgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        ICaliber.Instruction memory acctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(mgmtInstruction, acctInstruction);

        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 1);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], BORROW_POS_ID, inputAmount * PRICE_B_A, true);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), inputAmount * PRICE_B_A);

        // increase borrowModule rate
        borrowModule.setRateBps(10_000 * 2);

        caliber.accountForPosition(acctInstruction);

        (netAum, positionsValues, baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, 0);
        assertEq(positionsValues.length, 1);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], BORROW_POS_ID, 2 * inputAmount * PRICE_B_A, true);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), 0);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), inputAmount * PRICE_B_A);
    }

    function test_GetDetailedAum_MultiplePositions() public withTokenAsBT(address(baseToken)) {
        uint256 aInputAmount = 5e20;
        uint256 bInputAmount = 1e18;

        uint256 expectedNetAUM;

        // increase accounting token position
        deal(address(accountingToken), address(caliber), aInputAmount, true);
        expectedNetAUM += aInputAmount;

        deal(address(baseToken), address(borrowModule), bInputAmount, true);

        // create debt position (should not modify net aum)
        ICaliber.Instruction memory borrowMgmtInstruction =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), bInputAmount);
        ICaliber.Instruction memory borrowAcctInstruction = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(borrowModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(borrowMgmtInstruction, borrowAcctInstruction);

        // create supply position (should not modify net aum)
        ICaliber.Instruction memory supplyMgmtInstruction =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), bInputAmount);
        ICaliber.Instruction memory supplyAcctInstruction = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, LENDING_MARKET_POS_GROUP_ID, address(supplyModule)
        );
        vm.prank(mechanic);
        caliber.managePosition(supplyMgmtInstruction, supplyAcctInstruction);

        ICaliber.Instruction[] memory batch = new ICaliber.Instruction[](2);
        batch[0] = supplyAcctInstruction;
        batch[1] = borrowAcctInstruction;
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = LENDING_MARKET_POS_GROUP_ID;
        caliber.accountForPositionBatch(batch, groupIds);

        // check that AUM reflects all positions
        (uint256 netAum, bytes[] memory positionsValues, bytes[] memory baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, expectedNetAUM);
        assertEq(positionsValues.length, 2);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], BORROW_POS_ID, bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[1], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), 0);

        // double borrowModule rate
        borrowModule.setRateBps(2 * 10_000);

        caliber.accountForPositionBatch(batch, groupIds);
        expectedNetAUM -= bInputAmount * PRICE_B_A;

        (netAum, positionsValues, baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, expectedNetAUM);
        assertEq(positionsValues.length, 2);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], BORROW_POS_ID, 2 * bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[1], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), 0);

        // increase borrowModule rate
        borrowModule.setRateBps(1e2 * 10_000);

        caliber.accountForPositionBatch(batch, groupIds);
        expectedNetAUM = 0;

        (netAum, positionsValues, baseTokensValues) = caliber.getDetailedAum();
        assertEq(netAum, expectedNetAUM);
        assertEq(positionsValues.length, 2);
        assertEq(baseTokensValues.length, 2);
        _checkEncodedCaliberPosValue(positionsValues[0], BORROW_POS_ID, 1e2 * bInputAmount * PRICE_B_A, true);
        _checkEncodedCaliberPosValue(positionsValues[1], SUPPLY_POS_ID, bInputAmount * PRICE_B_A, false);
        _checkEncodedCaliberBTValue(baseTokensValues[0], address(accountingToken), aInputAmount);
        _checkEncodedCaliberBTValue(baseTokensValues[1], address(baseToken), 0);
    }
}
