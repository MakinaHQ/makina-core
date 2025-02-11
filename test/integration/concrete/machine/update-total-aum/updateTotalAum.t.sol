// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateTotalAum_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.updateTotalAum();
    }

    function test_RevertGiven_CaliberStale() public {
        skip(DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD + 1);
        vm.expectRevert(abi.encodeWithSelector(IMachine.CaliberAccountingStale.selector, block.chainid));
        machine.updateTotalAum();
    }

    function test_UpdateTotalAum_WithZeroAum() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_UnnoticedToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        // check that unnoticed token is not accounted for
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_IdleAccountingToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_IdleBaseToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(baseToken));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount * PRICE_B_A, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount * PRICE_B_A);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAum() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAumAndDebt()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        // fund caliber with accountingToken
        uint256 inputAmount = 3e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        uint256 inputAmount2 = 1e18;
        deal(address(baseToken), address(borrowModule), inputAmount2, true);

        ICaliber.Instruction[] memory borrowModuleInstructions = new ICaliber.Instruction[](2);
        borrowModuleInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount2);
        borrowModuleInstructions[1] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(borrowModuleInstructions);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValue()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 3e18;
        borrowModule.setRateBps(10_000 * 2);
        deal(address(baseToken), address(borrowModule), inputAmount, true);

        ICaliber.Instruction[] memory borrowModuleInstructions = new ICaliber.Instruction[](2);
        borrowModuleInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount);
        borrowModuleInstructions[1] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(borrowModuleInstructions);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 0);
    }

    function test_UpdateTotalAum_PositiveHubCaliberAumAndIdleToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        // fund machine with accountingToken
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        // fund caliber with accountingToken
        deal(address(accountingToken), address(caliber), inputAmount);
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(2 * inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), 2 * inputAmount);
    }

    function test_UpdateTotalAum_NegativeHubCaliberValueAndIdleToken()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        // fund machine with accountingToken
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);

        uint256 inputAmount2 = 1e18;
        borrowModule.setRateBps(10_000 * 2);
        deal(address(baseToken), address(borrowModule), inputAmount2, true);

        ICaliber.Instruction[] memory borrowModuleInstructions = new ICaliber.Instruction[](2);
        borrowModuleInstructions[0] =
            WeirollUtils._buildMockBorrowModuleBorrowInstruction(BORROW_POS_ID, address(borrowModule), inputAmount2);
        borrowModuleInstructions[1] = WeirollUtils._buildMockBorrowModuleAccountingInstruction(
            address(caliber), BORROW_POS_ID, address(borrowModule)
        );

        // open debt position in caliber
        vm.prank(mechanic);
        caliber.managePosition(borrowModuleInstructions);

        // check that machine total aum remains the same
        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastTotalAum(), inputAmount);
    }
}
