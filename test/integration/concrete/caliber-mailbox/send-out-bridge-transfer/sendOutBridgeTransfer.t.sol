// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract SendOutBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public transferId;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);
        bridgeAdapter = IBridgeAdapter(caliberMailbox.createBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, ""));
        caliberMailbox.setHubBridgeAdapter(IBridgeAdapter.Bridge.ACROSS_V3, hubBridgeAdapterAddr);
        vm.stopPrank();

        uint256 inputAmount = 2e18;
        deal(address(accountingToken), address(caliber), inputAmount, true);

        // schedule the transfer
        transferId = bridgeAdapter.nextOutTransferId();
        vm.prank(mechanic);
        caliber.transferToHubMachine(
            address(accountingToken), inputAmount, abi.encode(IBridgeAdapter.Bridge.ACROSS_V3, 0)
        );
    }

    function test_RevertGiven_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(ICaliber.RecoveryMode.selector);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");
    }

    function test_RevertWhen_CallerNotMechanic() public {
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");

        vm.prank(securityCouncil);
        vm.expectRevert(ICaliber.UnauthorizedOperator.selector);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, 0, "");
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.expectRevert(IBridgeController.BridgeAdapterDoesNotExist.selector);
        vm.prank(mechanic);
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.CIRCLE_CCTP, 0, "");
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter.nextOutTransferId();

        vm.expectRevert(IBridgeAdapter.InvalidTransferStatus.selector);
        vm.prank(address(mechanic));
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, nextOutTransferId, "");
    }

    function test_SendOutBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.SendOutBridgeTransfer(transferId);

        vm.prank(address(mechanic));
        caliberMailbox.sendOutBridgeTransfer(IBridgeAdapter.Bridge.ACROSS_V3, transferId, abi.encode(0));
    }
}
