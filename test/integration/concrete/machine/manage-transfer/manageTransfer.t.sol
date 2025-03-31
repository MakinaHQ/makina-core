// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "src/interfaces/IMachine.sol";
import {IOracleRegistry} from "src/interfaces/IOracleRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ManageTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    function test_RevertWhen_CallerNotAuthorized() public {
        vm.expectRevert(IMachine.UnauthorizedSender.selector);
        machine.manageTransfer(address(0), 0, "");
    }

    function test_ManageTransfer_EmptyBalance() public {
        vm.prank(address(caliber));
        machine.manageTransfer(address(baseToken), 0, "");
        assertFalse(machine.isIdleToken(address(baseToken)));
    }

    function test_ManageTransfer_EmptyBalanceAndNonPriceableToken() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        vm.prank(address(caliber));
        machine.manageTransfer(address(baseToken2), 0, "");
        assertFalse(machine.isIdleToken(address(baseToken2)));
    }

    function test_ManageTransfer_AccountingToken() public {
        uint256 inputAmount = 1;
        deal(address(accountingToken), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        accountingToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(accountingToken), inputAmount, "");
        // call passes and token is still registered as idle
        assertTrue(machine.isIdleToken(address(accountingToken)));
    }

    function test_RevertWhen_PositiveBalanceAndTokenNonPriceable() public {
        MockERC20 baseToken2 = new MockERC20("baseToken2", "BT2", 18);
        uint256 inputAmount = 1;
        deal(address(baseToken2), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken2.approve(address(machine), inputAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IOracleRegistry.PriceFeedRouteNotRegistered.selector, address(baseToken2))
        );
        machine.manageTransfer(address(baseToken2), inputAmount, "");
    }

    function test_ManageTransfer_BaseToken() public {
        uint256 inputAmount = 1;
        deal(address(baseToken), address(caliber), inputAmount, true);
        vm.startPrank(address(caliber));
        baseToken.approve(address(machine), inputAmount);
        machine.manageTransfer(address(baseToken), inputAmount, "");
        assertTrue(machine.isIdleToken(address(baseToken)));
    }
}
