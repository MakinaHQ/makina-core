// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";

import {CctpV2BridgeAdapter} from "src/bridge/adapters/CctpV2BridgeAdapter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MockCctpV2TokenMessenger} from "test/mocks/MockCctpV2TokenMessenger.sol";

import {CctpV2BridgeAdapter_Integration_Concrete_Test} from "../CctpV2BridgeAdapter.t.sol";

contract ReceiveCctpV2Message_CctpV2BridgeAdapter_Integration_Concrete_Test is
    CctpV2BridgeAdapter_Integration_Concrete_Test
{
    CctpV2BridgeAdapter internal cctpV2BridgeAdapter1;
    CctpV2BridgeAdapter internal cctpV2BridgeAdapter2;

    function setUp() public virtual override {
        CctpV2BridgeAdapter_Integration_Concrete_Test.setUp();

        cctpV2BridgeAdapter1 = CctpV2BridgeAdapter(address(bridgeAdapter1));
        cctpV2BridgeAdapter2 = CctpV2BridgeAdapter(address(bridgeAdapter2));
    }

    function test_RevertWhen_InvalidCctpMessage() public {
        vm.expectRevert(Errors.InvalidCctpMessage.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message("", "");
    }

    function test_RevertGiven_CctpMessageReceptionFailed() public {
        messageTransmitter.setFaultyMode(true);

        (bytes memory cctpMessage,) =
            _craftCctpV2MessageAndAttestation(address(token2), 0, address(0), address(0), 0, "");

        vm.expectRevert(Errors.CctpMessageReceptionFailed.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, "");
    }

    function test_RevertWhen_UnexpectedMessage() public {
        (bytes memory cctpMessage, bytes memory attestation) =
            _craftCctpV2MessageAndAttestation(address(token2), 0, address(0), address(bridgeAdapter1), 0, "");

        vm.expectRevert(Errors.UnexpectedMessage.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);
    }

    function test_RevertWhen_InvalidRecipientChainId() public {
        bytes memory encodedMessage =
            abi.encode(IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, 0, address(0), 0, address(0), 0));
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), 0, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidRecipientChainId.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);
    }

    function test_RevertWhen_InvalidOutputToken() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(1), 0, address(0), 0)
        );
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), 0, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidOutputToken.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);
    }

    function test_RevertWhen_MaxValueLossExceeded() public {
        // case 1: received amount is smaller than message's minOutputAmount
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(token1), 1)
        );
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), 0, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);

        // case 2: delta between received amount and message's inputAmount exceeds max bridge loss
        encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 1e18, address(token1), 0)
        );
        (cctpMessage, attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), 0, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.MaxValueLossExceeded.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);
    }

    function test_RevertWhen_InvalidInputAmount() public {
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(0, address(0), address(0), 0, chainId1, address(0), 0, address(token1), 1)
        );
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), 1, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectRevert(Errors.InvalidInputAmount.selector);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);
    }

    function test_ReceiveCctpV2Message_WithoutFee() public {
        uint256 inputAmount = 1e18;
        uint256 nextInTransferId = cctpV2BridgeAdapter1.nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0, address(0), address(0), 0, chainId1, address(0), inputAmount, address(token1), 0
            )
        );
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), inputAmount, address(0), address(bridgeAdapter1), 0, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectEmit(true, false, false, false, address(cctpV2BridgeAdapter1));
        emit IBridgeAdapter.InBridgeTransferReceived(nextInTransferId);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);

        assertEq(bridgeAdapter1.nextInTransferId(), nextInTransferId + 1);
    }

    function test_ReceiveCctpV2Message_WithFee() public {
        // set fee rate to 1 bps
        tokenMessenger.setMinFeeRate(CCTP_V2_FEE_MILLI_BPS);

        uint256 inputAmount = 1e18;
        uint256 fee = tokenMessenger.getMinFeeAmount(inputAmount);
        uint256 nextInTransferId = cctpV2BridgeAdapter1.nextInTransferId();
        bytes memory encodedMessage = abi.encode(
            IBridgeAdapter.BridgeMessage(
                0, address(0), address(0), 0, chainId1, address(0), inputAmount, address(token1), 0
            )
        );
        (bytes memory cctpMessage, bytes memory attestation) = _craftCctpV2MessageAndAttestation(
            address(token2), inputAmount, address(0), address(bridgeAdapter1), fee, encodedMessage
        );

        vm.prank(address(bridgeController1));
        cctpV2BridgeAdapter1.authorizeInBridgeTransfer(keccak256(encodedMessage));

        vm.expectEmit(true, false, false, false, address(cctpV2BridgeAdapter1));
        emit IBridgeAdapter.InBridgeTransferReceived(nextInTransferId);
        cctpV2BridgeAdapter1.receiveCctpV2Message(cctpMessage, attestation);

        assertEq(bridgeAdapter1.nextInTransferId(), nextInTransferId + 1);
        assertEq(token1.balanceOf(address(bridgeAdapter1)), inputAmount - fee);
        assertEq(token1.balanceOf(address(cctpFeeReceiver)), fee);
    }

    function _craftCctpV2MessageAndAttestation(
        address burnToken,
        uint256 amount,
        address sender,
        address receiver,
        uint256 feeExecuted,
        bytes memory encodedMessage
    ) internal view returns (bytes memory, bytes memory) {
        bytes32 _sender = bytes32(uint256(uint160(sender)));
        bytes32 _receiver = bytes32(uint256(uint160(receiver)));

        bytes memory cctpMessage = tokenMessenger.formatMessageForRelay(
            MockCctpV2TokenMessenger.RelayMessageParams({
                sourceDomain: CCTP_V2_SPOKE_DOMAIN,
                destinationDomain: CCTP_V2_HUB_DOMAIN,
                destinationCaller: _receiver,
                minFinalityThreshold: CCTP_V2_CONFIRMED_FINALITY_THRESHOLD,
                burnToken: burnToken,
                mintRecipient: _receiver,
                amount: amount,
                sender: _sender,
                maxFee: 0,
                feeExecuted: feeExecuted,
                hookData: encodedMessage
            })
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cctpAttesterPrivateKey, keccak256(cctpMessage));
        bytes memory attestation = abi.encodePacked(r, s, v);

        return (cctpMessage, attestation);
    }
}
