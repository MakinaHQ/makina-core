// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract TransferToHubCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.transferToHubCaliber(address(0), 0);

        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.UnauthorizedOperator.selector);
        machine.transferToHubCaliber(address(0), 0);
    }

    function test_RevertWhen_ProvidedTokenNonBaseToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.NotBaseToken.selector);
        machine.transferToHubCaliber(address(baseToken), inputAmount);
    }

    function test_RevertGiven_InsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.prank(address(mechanic));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(machine), 0, inputAmount)
        );
        machine.transferToHubCaliber(address(accountingToken), inputAmount);
    }

    function test_TransferToHubCaliber_AccountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(block.chainid, address(accountingToken), inputAmount);
        vm.prank(mechanic);
        machine.transferToHubCaliber(address(accountingToken), inputAmount);

        assertEq(accountingToken.balanceOf(address(machine)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_TransferToHubCaliber_BaseToken() public withTokenAsBT(address(baseToken)) {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(block.chainid, address(baseToken), inputAmount);
        vm.prank(mechanic);
        machine.transferToHubCaliber(address(baseToken), inputAmount);

        assertEq(baseToken.balanceOf(address(machine)), 0);
        assertEq(baseToken.balanceOf(address(caliber)), inputAmount);
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.transferToHubCaliber(address(0), 0);
    }
}
