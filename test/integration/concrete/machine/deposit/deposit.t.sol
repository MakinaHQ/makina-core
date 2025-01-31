// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract Deposit_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_cannotDepositWhenExceedingMaxMint() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);
        uint256 newShareLimit = expectedShares - 1;

        vm.prank(dao);
        machine.setShareLimit(newShareLimit);

        deal(address(accountingToken), address(this), inputAmount, true);
        accountingToken.approve(address(machine), inputAmount);
        // as the share supply is zero, maxMint is equal to shareLimit
        vm.expectRevert(abi.encodeWithSelector(IMachine.ExceededMaxMint.selector, expectedShares, newShareLimit));
        machine.deposit(inputAmount, address(this));
    }

    function test_deposit() public {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);

        deal(address(accountingToken), address(this), inputAmount, true);

        accountingToken.approve(address(machine), inputAmount);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(address(this), address(this), inputAmount, expectedShares);
        machine.deposit(inputAmount, address(this));

        assertEq(accountingToken.balanceOf(address(this)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(this)), expectedShares);
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_cannotDepositWithoutDepositorWhileInDepositorOnlyMode() public whileInDepositorOnlyMode {
        vm.expectRevert(IMachine.UnauthorizedDepositor.selector);
        machine.deposit(1e18, address(this));
    }

    function test_cannotDepositWhenExceedingMaxMintWhileInDepositorOnlyMode() public whileInDepositorOnlyMode {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);
        uint256 newShareLimit = expectedShares - 1;

        vm.prank(dao);
        machine.setShareLimit(newShareLimit);

        deal(address(accountingToken), machineDepositor, inputAmount, true);

        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), inputAmount);
        // as the share supply is zero, maxMint is equal to shareLimit
        vm.expectRevert(abi.encodeWithSelector(IMachine.ExceededMaxMint.selector, expectedShares, newShareLimit));
        machine.deposit(inputAmount, address(this));
    }

    function test_depositWhileInDepositorOnlyMode() public whileInDepositorOnlyMode {
        uint256 inputAmount = 1e18;
        uint256 expectedShares = machine.convertToShares(inputAmount);

        deal(address(accountingToken), machineDepositor, inputAmount, true);

        vm.startPrank(machineDepositor);
        accountingToken.approve(address(machine), inputAmount);
        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.Deposit(machineDepositor, address(this), inputAmount, expectedShares);
        machine.deposit(inputAmount, address(this));

        assertEq(accountingToken.balanceOf(address(this)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(machine.shareToken()).balanceOf(address(this)), expectedShares);
        assertEq(machine.lastTotalAum(), inputAmount);
    }

    function test_cannotDepositWhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.deposit(1e18, address(this));
    }
}
