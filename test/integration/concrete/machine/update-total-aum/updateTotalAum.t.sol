// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract UpdateTotalAum_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_cannotUpdateTotalAumWhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.updateTotalAum();
    }

    function test_cannotUpdateTotalAumWithStaleCaliber() public {
        vm.expectRevert(abi.encodeWithSelector(IMachine.CaliberAccountingStale.selector, block.chainid));
        machine.updateTotalAum();
    }

    function test_updateTotalAumWithZeroAum() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), 0);
    }

    function test_updateTotalAumDoesNotAccountForUnnotifiedToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(0, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), 0);
    }

    function test_updateTotalAumWithIdleAccountingToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), inputAmount);
    }

    function test_updateTotalAumWithIdleBaseToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount);

        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(baseToken));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount * PRICE_B_A, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), inputAmount * PRICE_B_A);
    }

    function test_updateTotalAumWithPositiveHubCaliberAum() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount);

        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), inputAmount);
    }

    function test_updateTotalAumWithPositiveHubCaliberAumAndIdleToken() public {
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        // fund machine with accountingToken
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount);
        vm.prank(machine.getMailbox(block.chainid));
        machine.notifyIncomingTransfer(address(accountingToken));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), inputAmount);

        // fund caliber with accountingToken
        deal(address(accountingToken), address(caliber), inputAmount);
        caliber.updateAndReportCaliberAUM(new ICaliber.Instruction[](0));

        vm.expectEmit(false, false, false, true, address(machine));
        emit IMachine.TotalAumUpdated(2 * inputAmount, block.timestamp);
        machine.updateTotalAum();
        assertEq(machine.lastReportedTotalAum(), 2 * inputAmount);
    }
}
