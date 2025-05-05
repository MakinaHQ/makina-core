// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract ManagePositionBatch_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(caliber), 3e18, true);

        ICaliber.Instruction[] memory mgmtInstructions = new ICaliber.Instruction[](1);
        mgmtInstructions[0] =
            WeirollUtils._build4626DepositInstruction(address(caliber), VAULT_POS_ID, address(vault), inputAmount);

        ICaliber.Instruction[] memory acctInstructions = new ICaliber.Instruction[](1);
        acctInstructions[0] =
            WeirollUtils._build4626AccountingInstruction(address(caliber), VAULT_POS_ID, address(vault));

        baseToken.scheduleReenter(
            MockERC20.Type.Before,
            address(caliber),
            abi.encodeCall(ICaliber.managePositionBatch, (mgmtInstructions, acctInstructions))
        );

        vm.expectRevert();
        vm.prank(mechanic);
        caliber.managePositionBatch(mgmtInstructions, acctInstructions);
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        ICaliber.Instruction[] memory dummyInstructions;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePositionBatch(dummyInstructions, dummyInstructions);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePositionBatch(dummyInstructions, dummyInstructions);
    }

    function test_RevertWhen_MismatchedLengths() public {
        ICaliber.Instruction[] memory mgmtInstructions = new ICaliber.Instruction[](2);
        ICaliber.Instruction[] memory acctInstructions = new ICaliber.Instruction[](1);

        vm.prank(mechanic);
        vm.expectRevert(Errors.MismatchedLengths.selector);
        caliber.managePositionBatch(mgmtInstructions, acctInstructions);
    }

    function test_ManagePositionBatch() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction[] memory mgmtInstructions = new ICaliber.Instruction[](2);
        mgmtInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        mgmtInstructions[1] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        ICaliber.Instruction[] memory acctInstructions = new ICaliber.Instruction[](2);
        acctInstructions[0] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );
        acctInstructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );

        uint256 expectedBorrowPosValue = inputAmount * PRICE_B_A;
        uint256 expectedSupplyPosValue = inputAmount * PRICE_B_A;

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionCreated(BORROW_POS_ID, expectedBorrowPosValue);

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionCreated(SUPPLY_POS_ID, expectedSupplyPosValue);

        vm.prank(mechanic);
        caliber.managePositionBatch(mgmtInstructions, acctInstructions);

        assertEq(caliber.getPositionsLength(), 2);
        assertEq(caliber.getPositionId(0), BORROW_POS_ID);
        assertEq(caliber.getPositionId(1), SUPPLY_POS_ID);
        assertEq(borrowModule.debtOf(address(caliber)), inputAmount);
        assertEq(supplyModule.collateralOf(address(caliber)), inputAmount);

        assertEq(caliber.getPosition(BORROW_POS_ID).value, expectedBorrowPosValue);
        assertEq(caliber.getPosition(BORROW_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(BORROW_POS_ID).isDebt, true);

        assertEq(caliber.getPosition(SUPPLY_POS_ID).value, expectedSupplyPosValue);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).lastAccountingTime, block.timestamp);
        assertEq(caliber.getPosition(SUPPLY_POS_ID).isDebt, false);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        ICaliber.Instruction[] memory dummyInstructions;

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePositionBatch(dummyInstructions, dummyInstructions);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliber.managePositionBatch(dummyInstructions, dummyInstructions);
    }

    function test_ManagePositionBatch_WhileInRecoveryMode() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 3e18;

        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction[] memory mgmtInstructions = new ICaliber.Instruction[](2);
        mgmtInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        mgmtInstructions[1] =
            WeirollUtils._buildMockSupplyModuleSupplyInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);

        ICaliber.Instruction[] memory acctInstructions = new ICaliber.Instruction[](2);
        acctInstructions[0] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );
        acctInstructions[1] = WeirollUtils._buildMockSupplyModuleAccountingInstruction(
            address(caliber), SUPPLY_POS_ID, address(supplyModule)
        );

        vm.prank(mechanic);
        caliber.managePositionBatch(mgmtInstructions, acctInstructions);

        _setRecoveryMode();

        mgmtInstructions[0] =
            WeirollUtils._buildMockSupplyModuleWithdrawInstruction(SUPPLY_POS_ID, address(supplyModule), inputAmount);
        mgmtInstructions[1] =
            WeirollUtils._buildMockBorrowModuleRepayInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);

        ICaliber.Instruction memory temp = acctInstructions[0];
        acctInstructions[0] = acctInstructions[1];
        acctInstructions[1] = temp;

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionClosed(SUPPLY_POS_ID);

        vm.expectEmit(true, false, false, false, address(caliber));
        emit ICaliber.PositionClosed(BORROW_POS_ID);

        vm.prank(securityCouncil);
        caliber.managePositionBatch(mgmtInstructions, acctInstructions);

        assertEq(caliber.getPositionsLength(), 0);
        assertEq(borrowModule.debtOf(address(caliber)), 0);
        assertEq(supplyModule.collateralOf(address(caliber)), 0);
    }

    function _setRecoveryMode() internal {
        vm.prank(securityCouncil);
        machine.setRecoveryMode(true);
    }
}
