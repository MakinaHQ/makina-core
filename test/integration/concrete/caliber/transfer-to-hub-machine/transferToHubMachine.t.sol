// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {WeirollUtils} from "test/utils/WeirollUtils.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract TransferToHubMachine_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    function test_cannotTransferToHubMachineWithoutMechanicWhileNotInRecoveryMode() public {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.transferToHubMachine(address(accountingToken), 1e18);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.transferToHubMachine(address(accountingToken), 1e18);
    }

    function test_cannotTransferToHubMachineWithoutPriceableToken() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1e18;
        deal(address(baseToken2), address(caliber), inputAmount, true);

        vm.prank(mechanic);
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        caliber.transferToHubMachine(address(baseToken2), inputAmount);
    }

    function test_cannotTransferToHubMachineWithInsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.prank(address(mechanic));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(caliber), 0, inputAmount)
        );
        caliber.transferToHubMachine(address(accountingToken), inputAmount);
    }

    function test_transferToHubMachine() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.TransferToHubMachine(address(accountingToken), inputAmount);
        vm.prank(mechanic);
        caliber.transferToHubMachine(address(accountingToken), inputAmount);

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(caliber.mailbox()), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
    }

    function test_cannotTransferToHubMachineWithoutSecurityCouncilWhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.transferToHubMachine(address(accountingToken), 1e18);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliber.transferToHubMachine(address(accountingToken), 1e18);
    }

    function test_cannotTransferToHubMachineWithoutPriceableTokenWhileInRecoveryMode() public whileInRecoveryMode {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1e18;
        deal(address(baseToken2), address(caliber), inputAmount, true);

        vm.prank(securityCouncil);
        vm.expectRevert(IOracleRegistry.FeedDataNotRegistered.selector);
        caliber.transferToHubMachine(address(baseToken2), inputAmount);
    }

    function test_cannotTransferToHubMachineWithInsufficientBalanceWhileInRecoveryMode() public whileInRecoveryMode {
        uint256 inputAmount = 1e18;

        vm.prank(address(securityCouncil));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(caliber), 0, inputAmount)
        );
        caliber.transferToHubMachine(address(accountingToken), inputAmount);
    }

    function test_transferToHubMachineWhileInRecoveryMode() public whileInRecoveryMode {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.TransferToHubMachine(address(accountingToken), inputAmount);
        vm.prank(securityCouncil);
        caliber.transferToHubMachine(address(accountingToken), inputAmount);

        assertEq(accountingToken.balanceOf(address(caliber)), 0);
        assertEq(accountingToken.balanceOf(caliber.mailbox()), 0);
        assertEq(accountingToken.balanceOf(address(machine)), inputAmount);
    }
}
