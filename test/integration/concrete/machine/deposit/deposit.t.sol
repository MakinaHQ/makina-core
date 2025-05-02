// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Deposit_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_ReentrantCall() public {
        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(machine), abi.encodeCall(IMachine.deposit, (0, address(0), 0))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        vm.prank(machineDepositor);
        machine.deposit(0, address(0), 0);
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMakinaGovernable.RecoveryMode.selector);
        machine.deposit(1e18, address(this), 0);
    }

    function test_RevertWhen_CallerNotDepositor() public {
        vm.expectRevert(IMachine.UnauthorizedDepositor.selector);
        machine.deposit(1e18, address(this), 0);
    }

    function test_RevertGiven_MaxMintExceeded() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);
        uint256 newShareLimit = expectedShares - 1;

        vm.prank(riskManager);
        machine.setShareLimit(newShareLimit);

        deal(address(accountingToken), machineDepositor, inputAmount, true);

        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), inputAmount);
        // as the share supply is zero, maxMint is equal to shareLimit
        vm.expectRevert(abi.encodeWithSelector(IMachine.ExceededMaxMint.selector, expectedShares, newShareLimit));
        machine.deposit(inputAmount, address(this), 0);
    }

    function test_RevertWhen_SlippageProtectionTriggered() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);

        deal(address(accountingToken), machineDepositor, inputAmount, true);

        accountingToken.approve(address(machine), inputAmount);

        vm.expectRevert(IMachine.SlippageProtection.selector);
        vm.prank(machineDepositor);
        machine.deposit(inputAmount, address(this), expectedShares + 1);
    }

    function test_Deposit() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);

        deal(address(accountingToken), machineDepositor, inputAmount, true);

        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), inputAmount);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(machineDepositor, address(this), inputAmount, expectedShares);
        machine.deposit(inputAmount, address(this), expectedShares);

        assertEq(accountingToken.balanceOf(machineDepositor), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(this)), expectedShares);
        assertEq(machine.lastTotalAum(), inputAmount);
    }
}
