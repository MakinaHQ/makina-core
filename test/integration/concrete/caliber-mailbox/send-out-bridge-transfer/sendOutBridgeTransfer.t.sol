// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract SendOutBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public transferId;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(caliberMailbox.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        caliberMailbox.setHubBridgeAdapter(ACROSS_V3_BRIDGE_ID, hubBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        // schedule the transfer
        transferId = bridgeAdapter.nextOutTransferId();
        vm.prank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(ACROSS_V3_BRIDGE_ID, inputAmount)
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(CIRCLE_CCTP_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_OutTransferDisabled() public {
        vm.prank(riskManagerTimelock);
        caliberMailbox.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);

        vm.expectRevert(Errors.OutTransferDisabled.selector);
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextOutTransferId, "");
    }

    function test_SendOutBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferSent(transferId);

        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(0));
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertWhen_BridgeAdapterDoesNotExist_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(securityCouncil);
        caliberMailbox.sendOutBridgeTransfer(CIRCLE_CCTP_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_OutTransferDisabled_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.prank(riskManagerTimelock);
        caliberMailbox.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);

        vm.expectRevert(Errors.OutTransferDisabled.selector);
        vm.prank(securityCouncil);
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_InvalidTransferStatus_WhileInRecoveryMode() public whileInRecoveryMode {
        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(securityCouncil));
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextOutTransferId, "");
    }

    function test_SendOutBridgeTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferSent(transferId);

        vm.prank(address(securityCouncil));
        caliberMailbox.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(0));
    }
}
