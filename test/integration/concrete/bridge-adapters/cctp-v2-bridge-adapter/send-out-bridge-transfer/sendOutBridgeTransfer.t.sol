// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockCctpV2TokenMessenger} from "test/mocks/MockCctpV2TokenMessenger.sol";
import {Errors} from "src/libraries/Errors.sol";

import {CctpV2BridgeAdapter_Integration_Concrete_Test} from "../CctpV2BridgeAdapter.t.sol";

contract SendOutBridgeTransfer_CctpV2BridgeAdapter_Integration_Concrete_Test is
    CctpV2BridgeAdapter_Integration_Concrete_Test
{
    function test_RevertWhen_ReentrantCall() public {
        uint256 inputAmount = 1e18;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), 0
        );

        token1.scheduleReenter(
            MockERC20.Type.Before,
            address(bridgeAdapter1),
            abi.encodeCall(bridgeAdapter1.sendOutBridgeTransfer, (0, ""))
        );

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint32(0)));
    }

    function test_RevertWhen_CallerNotController() public {
        vm.expectRevert(Errors.NotController.selector);
        bridgeAdapter1.sendOutBridgeTransfer(0, abi.encode(uint32(0)));
    }

    function test_RevertGiven_InvalidTransferStatus() public {
        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();
        uint256 inputAmount = 1e18;

        // transfer not sheduled
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        vm.prank(address(bridgeController1));
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint32(0)));

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));
        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(chainId2, address(0), address(token1), inputAmount, address(token2), 0);

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint32(0)));

        // transfer already sent
        vm.expectRevert(Errors.InvalidTransferStatus.selector);
        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(uint32(0)));
    }

    function test_SendOutBridgeTransfer_WithoutFee() public {
        uint256 inputAmount = 1e18;
        uint256 minOutputAmount = inputAmount;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                nextOutTransferId,
                address(bridgeAdapter1),
                address(bridgeAdapter2),
                block.chainid,
                chainId2,
                address(token1),
                inputAmount,
                address(token2),
                minOutputAmount
            )
        );

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), minOutputAmount
        );

        bytes32 sender = bytes32(uint256(uint160(address(bridgeAdapter1))));
        bytes32 receiver = bytes32(uint256(uint160(address(bridgeAdapter2))));

        bytes32 messageDigest = keccak256(
            tokenMessenger.formatMessageForRelay(
                MockCctpV2TokenMessenger.RelayMessageParams({
                    sourceDomain: CCTP_V2_HUB_DOMAIN,
                    destinationDomain: CCTP_V2_SPOKE_DOMAIN,
                    destinationCaller: receiver,
                    minFinalityThreshold: CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
                    burnToken: address(token1),
                    mintRecipient: receiver,
                    amount: inputAmount,
                    sender: sender,
                    maxFee: 0,
                    feeExecuted: 0,
                    hookData: encodedMessage
                })
            )
        );

        uint256 supplyBefore = token1.totalSupply();

        vm.expectEmit(false, false, false, true, address(tokenMessenger));
        emit MockCctpV2TokenMessenger.DepositForBurnWithHook(messageDigest);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD));

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(tokenMessenger)), 0);
        assertEq(token1.totalSupply(), supplyBefore - inputAmount);
    }

    function test_SendOutBridgeTransfer_WithFee() public {
        // set fee rate to 1 bps
        tokenMessenger.setMinFeeRate(CCTP_V2_FEE_MILLI_BPS);

        uint256 inputAmount = 1e18;
        uint256 fee = tokenMessenger.getMinFeeAmount(inputAmount);
        uint256 minOutputAmount = inputAmount - fee;

        uint256 nextOutTransferId = bridgeAdapter1.nextOutTransferId();

        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                nextOutTransferId,
                address(bridgeAdapter1),
                address(bridgeAdapter2),
                block.chainid,
                chainId2,
                address(token1),
                inputAmount,
                address(token2),
                minOutputAmount
            )
        );

        deal(address(token1), address(bridgeController1), inputAmount, true);

        vm.startPrank(address(bridgeController1));

        token1.approve(address(bridgeAdapter1), inputAmount);
        bridgeAdapter1.scheduleOutBridgeTransfer(
            chainId2, address(bridgeAdapter2), address(token1), inputAmount, address(token2), minOutputAmount
        );

        bytes32 sender = bytes32(uint256(uint160(address(bridgeAdapter1))));
        bytes32 receiver = bytes32(uint256(uint160(address(bridgeAdapter2))));

        bytes32 cctpMessageDigest = keccak256(
            tokenMessenger.formatMessageForRelay(
                MockCctpV2TokenMessenger.RelayMessageParams({
                    sourceDomain: CCTP_V2_HUB_DOMAIN,
                    destinationDomain: CCTP_V2_SPOKE_DOMAIN,
                    destinationCaller: receiver,
                    minFinalityThreshold: CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
                    burnToken: address(token1),
                    mintRecipient: receiver,
                    amount: inputAmount,
                    sender: sender,
                    maxFee: fee,
                    feeExecuted: 0,
                    hookData: encodedMessage
                })
            )
        );

        uint256 supplyBefore = token1.totalSupply();

        vm.expectEmit(false, false, false, true, address(tokenMessenger));
        emit MockCctpV2TokenMessenger.DepositForBurnWithHook(cctpMessageDigest);

        vm.expectEmit(true, false, false, false, address(bridgeAdapter1));
        emit IBridgeAdapter.OutBridgeTransferSent(nextOutTransferId);

        bridgeAdapter1.sendOutBridgeTransfer(nextOutTransferId, abi.encode(CCTP_V2_CONFIRMED_FINALITY_THRESHOLD));

        assertEq(IERC20(address(token1)).balanceOf(address(bridgeController1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(bridgeAdapter1)), 0);
        assertEq(IERC20(address(token1)).balanceOf(address(tokenMessenger)), 0);
        assertEq(token1.totalSupply(), supplyBefore - inputAmount);
    }
}
