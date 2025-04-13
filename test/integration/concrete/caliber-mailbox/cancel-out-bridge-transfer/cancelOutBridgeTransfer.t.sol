// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract CancelOutBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public acrossV3DepositId;
    uint256 public transferId;
    uint256 public inputAmount;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);
        bridgeAdapter = IBridgeAdapter(
            caliberMailbox.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "")
        );
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, hubBridgeAdapterAddr);
        vm.stopPrank();

        acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();
        transferId = bridgeAdapter.nextOutTransferId();
        inputAmount = 1e18;

        deal(address(accountingToken), address(caliber), inputAmount, true);

        vm.prank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, inputAmount)
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        vm.expectRevert(IBridgeAdapter.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0);
    }

    function test_CancelScheduledTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.CancelOutBridgeTransfer(transferId);

        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_CancelSentTransfer_WithoutFee() public {
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(0));

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.CancelOutBridgeTransfer(transferId);

        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0);

        vm.prank(mechanic);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0);
    }

    function test_CancelScheduledTransfer_WhileInRecoveryMode() public {
        vm.prank(dao);
        caliber.setRecoveryMode(true);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.CancelOutBridgeTransfer(transferId);

        vm.prank(securityCouncil);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_CancelSentTransfer_WithoutFee_WhileInRecoveryMode() public {
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(0));

        vm.prank(dao);
        caliber.setRecoveryMode(true);

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.CancelOutBridgeTransfer(transferId);

        vm.prank(securityCouncil);
        caliberMailbox.cancelOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }
}
