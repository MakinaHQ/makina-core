// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract CancelOutBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter internal bridgeAdapter;

    uint256 internal acrossV3DepositId;
    uint256 internal transferId;
    uint256 internal inputAmount;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(caliberMailbox.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        caliberMailbox.setHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr);
        vm.stopPrank();

        acrossV3DepositId = acrossV3SpokePool.numberOfDeposits();
        transferId = bridgeAdapter.nextOutTransferId();
        inputAmount = 1e18;

        deal(address(accountingToken), address(caliber), inputAmount, true);

        skip(DEFAULT_CALIBER_COOLDOWN_DURATION);

        vm.prank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, inputAmount)
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_CancelScheduledTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_CancelSentTransfer_WithoutFee() public {
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(0));

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(mechanic);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_CancelScheduledTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(securityCouncil);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, inputAmount);

        (address token, uint256 amount) = abi.decode(accountingData.bridgesOut[0], (address, uint256));
        assertEq(token, address(accountingToken));
        assertEq(amount, 0);
    }

    function test_CancelSentTransfer_WithoutFee_WhileInRecoveryMode() public {
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(0));

        vm.prank(securityCouncil);
        caliberMailbox.setRecoveryMode(true);

        acrossV3SpokePool.cancelTransfer(acrossV3DepositId);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferCancelled(transferId);

        vm.prank(securityCouncil);
        caliberMailbox.cancelOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), inputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);

        ICaliberMailbox.SpokeCaliberAccountingData memory accountingData =
            caliberMailbox.getSpokeCaliberAccountingData();
        assertEq(accountingData.bridgesIn.length, 0);
        assertEq(accountingData.bridgesOut.length, 1);
        assertEq(accountingData.netAum, inputAmount);
        (address token, uint256 amount) = abi.decode(accountingData.bridgesOut[0], (address, uint256));
        assertEq(token, address(accountingToken));
        assertEq(amount, 0);
    }
}
