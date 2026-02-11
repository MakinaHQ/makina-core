// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract SendOutBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter internal bridgeAdapter;

    uint256 internal transferId;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, ACROSS_V3_BRIDGE_ID, spokeBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        // schedule the transfer
        transferId = bridgeAdapter.nextOutTransferId();
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            ACROSS_V3_BRIDGE_ID, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.RecoveryMode.selector);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(Errors.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(DUMMY_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_OutTransferDisabled() public {
        vm.prank(riskManagerTimelock);
        machine.setOutTransferEnabled(ACROSS_V3_BRIDGE_ID, false);

        vm.expectRevert(Errors.OutTransferDisabled.selector);
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0, "");
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(mechanic));
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextOutTransferId, "");
    }

    function test_SendOutBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.OutBridgeTransferSent(transferId);

        vm.prank(address(mechanic));
        machine.sendOutBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId, abi.encode(0));
    }
}
