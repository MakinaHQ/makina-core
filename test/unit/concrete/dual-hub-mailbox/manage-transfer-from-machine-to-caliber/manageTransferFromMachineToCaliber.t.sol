// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {IHubDualMailbox} from "src/interfaces/IHubDualMailbox.sol";
import {IMachineMailbox} from "src/interfaces/IMachineMailbox.sol";

import {HubDualMailbox_Unit_Concrete_Test} from "../HubDualMailbox.t.sol";

contract ManageTransferFromMachineToCaliber_Unit_Concrete_Test is HubDualMailbox_Unit_Concrete_Test {
    function test_cannotManageTransferFromMachineToCaliberWithoutMachine() public {
        vm.expectRevert(IMachineMailbox.NotMachine.selector);
        hubDualMailbox.manageTransferFromMachineToCaliber(address(accountingToken), 1e18);
    }

    function test_cannotManageTransferFromMachineToCaliberWithoutBaseToken() public {
        vm.prank(machine);
        vm.expectRevert(IHubDualMailbox.NotBaseToken.selector);
        hubDualMailbox.manageTransferFromMachineToCaliber(address(baseToken), 1e18);
    }

    function test_cannotManageTransferFromMachineToCaliberWithInsufficientAllowance() public {
        uint256 inputAmount = 1e18;

        vm.prank(address(machine));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(hubDualMailbox), 0, inputAmount
            )
        );
        hubDualMailbox.manageTransferFromMachineToCaliber(address(accountingToken), inputAmount);
    }

    function test_cannotManageTransferFromMachineToCaliberWithInsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.startPrank(address(machine));
        accountingToken.approve(address(hubDualMailbox), inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(machine), 0, inputAmount)
        );
        hubDualMailbox.manageTransferFromMachineToCaliber(address(accountingToken), inputAmount);
    }

    function test_manageTransferFromMachineToCaliber() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.startPrank(machine);
        accountingToken.approve(address(hubDualMailbox), inputAmount);
        hubDualMailbox.manageTransferFromMachineToCaliber(address(accountingToken), inputAmount);
        vm.stopPrank();

        assertEq(accountingToken.balanceOf(address(machine)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
    }
}
