// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CaliberMailbox_Integration_Concrete_Test} from "../CaliberMailbox.t.sol";

contract ClaimInBridgeTransfer_Integration_Concrete_Test is CaliberMailbox_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public transferId;
    uint256 public inputAmount;
    uint256 public outputAmount;

    function setUp() public override {
        CaliberMailbox_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), hubChainId, hubAccountingTokenAddr);
        bridgeAdapter =
            IBridgeAdapter(caliberMailbox.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        vm.stopPrank();

        inputAmount = 1e18;

        outputAmount = 9e17;

        // authorize the transfer on recipient side
        transferId = bridgeAdapter.nextOutTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                transferId,
                hubBridgeAdapterAddr,
                address(bridgeAdapter),
                hubChainId,
                block.chainid,
                hubAccountingTokenAddr,
                inputAmount,
                address(accountingToken),
                outputAmount
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        caliberMailbox.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);

        // simulate the incoming transfer
        deal(address(accountingToken), address(bridgeAdapter), outputAmount, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(address(bridgeAdapter)).handleV3AcrossMessage(
            address(accountingToken), outputAmount, address(0), encodedMessage
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextInTransferId = bridgeAdapter.nextInTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextInTransferId);
    }

    function test_ClaimInBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ClaimInBridgeTransfer(transferId);

        vm.prank(mechanic);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), outputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_ClaimInBridgeTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.ClaimInBridgeTransfer(transferId);

        vm.prank(securityCouncil);
        caliberMailbox.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(caliber)), outputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }
}
