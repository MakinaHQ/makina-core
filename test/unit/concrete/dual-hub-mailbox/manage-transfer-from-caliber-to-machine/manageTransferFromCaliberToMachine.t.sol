// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {HubDualMailbox_Unit_Concrete_Test} from "../HubDualMailbox.t.sol";

contract ManageTransferFromCaliberToMachine_Unit_Concrete_Test is HubDualMailbox_Unit_Concrete_Test {
    function test_cannotManageTransferFromCaliberToMachineWithoutCaliber() public {
        vm.expectRevert(ICaliberMailbox.NotCaliber.selector);
        hubDualMailbox.manageTransferFromCaliberToMachine(address(accountingToken), 1e18);
    }

    function test_cannotManageTransferFromCaliberToMachineWithInsufficientAllowance() public {
        uint256 inputAmount = 1e18;

        vm.prank(address(caliber));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(hubDualMailbox), 0, inputAmount
            )
        );
        hubDualMailbox.manageTransferFromCaliberToMachine(address(accountingToken), inputAmount);
    }

    function test_cannotManageTransferFromCaliberToMachineWithInsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.startPrank(address(caliber));
        accountingToken.approve(address(hubDualMailbox), inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(caliber), 0, inputAmount)
        );
        hubDualMailbox.manageTransferFromCaliberToMachine(address(accountingToken), inputAmount);
    }

    function test_manageTransferFromCaliberToMachine() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        vm.startPrank(address(caliber));
        accountingToken.approve(address(hubDualMailbox), inputAmount);
        hubDualMailbox.manageTransferFromCaliberToMachine(address(accountingToken), inputAmount);
        vm.stopPrank();

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(address(hubDualMailbox)), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
    }
}
