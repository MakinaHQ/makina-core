// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract CancelOutBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public acrossV3DepositId;
    uint256 public transferId;
    uint256 public inputAmount;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        vm.stopPrank();

        acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();
        transferId = bridgeAdapter.nextOutTransferId();
        inputAmount = 1e18;

        deal(address(accountingToken), address(machine), inputAmount, true);

        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_CancelScheduledTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_CancelSentTransfer_WithoutFee() public {
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(1 hours));

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(mechanic);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_CancelScheduledTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(securityCouncil);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_CancelSentTransfer_WithoutFee_WhileInRecoveryMode() public {
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(1 hours));

        vm.prank(securityCouncil);
        machine.setRecoveryMode(true);

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(securityCouncil);
        machine.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }
}
