// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachine} from "src/interfaces/IMachine.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract TransferToCaliber_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_cannotTransferToCaliberWithoutMechanicWhileNotInRecoveryMode() public {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        machine.transferToCaliber(address(accountingToken), 1e18, block.chainid);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        machine.transferToCaliber(address(accountingToken), 1e18, block.chainid);
    }

    function test_cannotTransferToCaliberWithoutBaseToken() public {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(caliber), inputAmount, true);

        vm.prank(mechanic);
        vm.expectRevert(IHubDualMailbox.NotBaseToken.selector);
        machine.transferToCaliber(address(baseToken), inputAmount, block.chainid);
    }

    function test_cannotTransferToCaliberWithInsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.prank(address(mechanic));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(machine), 0, inputAmount)
        );
        machine.transferToCaliber(address(accountingToken), inputAmount, block.chainid);
    }

    function test_transferToCaliber_accountingToken() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(block.chainid, address(accountingToken), inputAmount);
        vm.prank(mechanic);
        machine.transferToCaliber(address(accountingToken), inputAmount, block.chainid);

        assertEq(accountingToken.balanceOf(address(machine)), 0);
        assertEq(accountingToken.balanceOf(caliber.mailbox()), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
    }

    function test_transferToCaliber_baseToken()
        public
        withTokenAsBT(address(baseToken), HUB_CALIBER_BASE_TOKEN_1_POS_ID)
    {
        uint256 inputAmount = 1e18;
        deal(address(baseToken), address(machine), inputAmount, true);

        vm.expectEmit(true, true, false, true, address(machine));
        emit IMachine.TransferToCaliber(block.chainid, address(baseToken), inputAmount);
        vm.prank(mechanic);
        machine.transferToCaliber(address(baseToken), inputAmount, block.chainid);

        assertEq(baseToken.balanceOf(address(machine)), 0);
        assertEq(baseToken.balanceOf(caliber.mailbox()), 0);
        assertEq(baseToken.balanceOf(address(caliber)), inputAmount);
    }

    function test_cannotTransferToCaliberWhileInRecoveryMode() public whileInRecoveryMode {
        vm.prank(securityCouncil);
        vm.expectRevert(IMachine.RecoveryMode.selector);
        machine.transferToCaliber(address(accountingToken), 1e18, block.chainid);
    }
}
