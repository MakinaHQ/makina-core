// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {IAcrossV3MessageHandler} from "src/interfaces/IAcrossV3MessageHandler.sol";
import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PerChainData} from "test/utils/WormholeQueryTestHelpers.sol";
import {WormholeQueryTestHelpers} from "test/utils/WormholeQueryTestHelpers.sol";

import {Machine_Integration_Concrete_Test} from "../Machine.t.sol";

contract ClaimInBridgeTransfer_Integration_Concrete_Test is Machine_Integration_Concrete_Test {
    IBridgeAdapter public bridgeAdapter;

    uint256 public transferId;
    uint256 public inputAmount;
    uint256 public outputAmount;

    function setUp() public override {
        Machine_Integration_Concrete_Test.setUp();

        vm.startPrank(dao);
        tokenRegistry.setToken(address(accountingToken), SPOKE_CHAIN_ID, spokeAccountingTokenAddr);
        machine.setSpokeCaliber(SPOKE_CHAIN_ID, spokeCaliberMailboxAddr, new uint16[](0), new address[](0));
        bridgeAdapter =
            IBridgeAdapter(machine.createBridgeAdapter(ACROSS_V3_BRIDGE_ID, DEFAULT_MAX_BRIDGE_LOSS_BPS, ""));
        vm.stopPrank();

        inputAmount = 1e18;

        outputAmount = 999e15;

        // authorize the transfer on recipient side
        transferId = bridgeAdapter.nextOutTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                transferId,
                spokeBridgeAdapterAddr,
                address(bridgeAdapter),
                SPOKE_CHAIN_ID,
                block.chainid,
                spokeAccountingTokenAddr,
                inputAmount,
                address(accountingToken),
                outputAmount
            )
        );
        bytes32 messageHash = keccak256(encodedMessage);
        vm.prank(mechanic);
        machine.authorizeInBridgeTransfer(ACROSS_V3_BRIDGE_ID, messageHash);

        // simulate the caliber having sent the transfer
        uint64 blockNum = 1e10;
        uint64 blockTime = uint64(block.timestamp);
        bytes[] memory cBridgeIn;
        bytes[] memory cBridgeOut = new bytes[](1);
        cBridgeOut[0] = abi.encode(spokeAccountingTokenAddr, inputAmount);
        ICaliberMailbox.SpokeCaliberAccountingData memory queriedData =
            _buildSpokeCaliberAccountingDataWithTransfers(false, 0, cBridgeIn, cBridgeOut);
        PerChainData[] memory perChainData = WormholeQueryTestHelpers.buildSinglePerChainData(
            WORMHOLE_SPOKE_CHAIN_ID, blockNum, blockTime, spokeCaliberMailboxAddr, abi.encode(queriedData)
        );
        (bytes memory response, GuardianSignature[] memory signatures) = WormholeQueryTestHelpers.prepareResponses(
            perChainData, "", ICaliberMailbox.getSpokeCaliberAccountingData.selector, ""
        );
        machine.updateSpokeCaliberAccountingData(response, signatures);

        // simulate the incoming transfer
        deal(address(accountingToken), address(bridgeAdapter), outputAmount, true);
        vm.prank(address(acrossV3SpokePool));
        IAcrossV3MessageHandler(address(bridgeAdapter)).handleV3AcrossMessage(
            address(accountingToken), outputAmount, address(0), encodedMessage
        );
    }

    function test_RevertWhen_CallerNotMechanic_WhileNotInRecoveryMode() public {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(securityCouncil);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextInTransferId = bridgeAdapter.nextInTransferId();

        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(mechanic);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, nextInTransferId);
    }

    function test_ClaimInBridgeTransfer() public {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.InBridgeTransferClaimed(transferId);

        vm.prank(mechanic);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), outputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }

    function test_RevertWhen_CallerNotSC_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);

        vm.prank(mechanic);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, 0);
    }

    function test_ClaimInBridgeTransfer_WhileInRecoveryMode() public whileInRecoveryMode {
        vm.expectEmit(true, false, false, false, address(bridgeAdapter));
        emit IBridgeAdapter.InBridgeTransferClaimed(transferId);

        vm.prank(securityCouncil);
        machine.claimInBridgeTransfer(ACROSS_V3_BRIDGE_ID, transferId);

        assertEq(IERC20(address(accountingToken)).balanceOf(address(machine)), outputAmount);
        assertEq(IERC20(address(accountingToken)).balanceOf(address(bridgeAdapter)), 0);
    }
}
