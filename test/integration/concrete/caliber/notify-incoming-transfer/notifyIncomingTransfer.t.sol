// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ICaliber} from "src/interfaces/ICaliber.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Caliber_Integration_Concrete_Test} from "../Caliber.t.sol";

contract NotifyIncomingTransfer_Integration_Concrete_Test is Caliber_Integration_Concrete_Test {
    address public hubMachineEndpoint;

    function setUp() public virtual override {
        Caliber_Integration_Concrete_Test.setUp();
        hubMachineEndpoint = caliber.hubMachineEndpoint();
    }

    function test_RevertWhen_ReentrantCall() public {
        vm.startPrank(hubMachineEndpoint);

        accountingToken.scheduleReenter(
            MockERC20.Type.Before, address(caliber), abi.encodeCall(caliber.notifyIncomingTransfer, (address(0), 0))
        );

        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        caliber.notifyIncomingTransfer(address(accountingToken), 0);
    }

    function test_RevertWhen_CallerNotHubMachineEndpoint() public {
        vm.expectRevert(Errors.NotMachineEndpoint.selector);
        caliber.notifyIncomingTransfer(address(0), 0);
    }

    function test_RevertWhen_TokenNotBaseToken() public {
        vm.prank(hubMachineEndpoint);
        vm.expectRevert(Errors.NotBaseToken.selector);
        caliber.notifyIncomingTransfer(address(baseToken), 0);
    }

    function test_RevertGiven_InsufficientAllowance() public {
        uint256 inputAmount = 1e18;

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(caliber), 0, inputAmount)
        );
        vm.prank(address(hubMachineEndpoint));
        caliber.notifyIncomingTransfer(address(accountingToken), inputAmount);
    }

    function test_RevertGiven_InsufficientBalance() public {
        uint256 inputAmount = 1e18;

        vm.startPrank(address(hubMachineEndpoint));
        accountingToken.approve(address(caliber), inputAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(hubMachineEndpoint), 0, inputAmount
            )
        );
        caliber.notifyIncomingTransfer(address(accountingToken), inputAmount);
    }

    function test_NotifyIncomingTransfer() public {
        uint256 inputAmount = 1e18;
        deal(address(accountingToken), address(hubMachineEndpoint), inputAmount, true);

        vm.prank(address(hubMachineEndpoint));
        accountingToken.approve(address(caliber), inputAmount);

        vm.expectEmit(true, false, false, true, address(caliber));
        emit ICaliber.IncomingTransfer(address(accountingToken), inputAmount);
        vm.prank(hubMachineEndpoint);
        caliber.notifyIncomingTransfer(address(accountingToken), inputAmount);

        assertEq(accountingToken.balanceOf(address(hubMachineEndpoint)), 0);
        assertEq(accountingToken.balanceOf(address(caliber)), inputAmount);
    }
}
