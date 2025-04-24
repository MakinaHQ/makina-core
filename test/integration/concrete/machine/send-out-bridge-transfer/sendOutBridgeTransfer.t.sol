// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {IMachine} from "src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "src/interfaces/IMakinaGovernable.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract SendOutBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public transferId;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        bridgeAdapter = IBridgeAdapter(
            machine.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, DEFAULT_MAX_BRIDGE_LOSS_BPS, "")
        );
        machine.setSpokeCaliber(
            SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new IBridgeAdapter.Bridge[](0), new address[](0)
        );
        machine.setSpokeBridgeAdapter(SPOKE_CHAIN_ID, IBridgeAdapter.Bridge.ACROSS_V3, spokeBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(machine), inputAmount, true);

        // schedule the transfer
        transferId = bridgeAdapter.nextOutTransferId();
        vm.prank(mechanic);
        machine.transferToSpokeCaliber(
            IBridgeAdapter.Bridge.ACROSS_V3, SPOKE_CHAIN_ID, address(accountingToken), inputAmount, inputAmount
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(IMakinaGovernable.RecoveryMode.selector);
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");

        vm.prank(securityCouncil);
        vm.expectRevert(IMakinaGovernable.UnauthorizedCaller.selector);
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");
    }

    function test_RevertGiven_BridgeAdapterDoesNotExist() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.CIRCLE_CCTP, 0, "");
    }

    function test_RevertGiven_OutTransferDisabled() public {
        vm.prank(riskManagerTimelock);
        machine.setOutTransferEnabled(IBridgeAdapter.Bridge.ACROSS_V3, false);

        vm.expectRevert(IBridgeController.OutTransferDisabled.selector);
        vm.prank(mechanic);
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();

        vm.expectRevert(IBridgeAdapter.InvalidTransferStatus.selector);
        vm.prank(address(mechanic));
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, nextOutTransferId, "");
    }

    function test_SendOutBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.SendOutBridgeTransfer(transferId);

        vm.prank(address(mechanic));
        machine.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(0));
    }
}
