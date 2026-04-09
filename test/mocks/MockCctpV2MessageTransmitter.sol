// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ICctpV2MessageTransmitter} from "src/interfaces/ICctpV2MessageTransmitter.sol";
import {MockCctpV2TokenMessenger} from "./MockCctpV2TokenMessenger.sol";

/// @dev MockCctpV2MessageTransmitter contract for testing use only
contract MockCctpV2MessageTransmitter is ICctpV2MessageTransmitter {
    event ReceiveMessage(bytes message, bytes attestation);

    error InvalidAttestation();
    error InvalidMessage();

    bool public faultyMode;

    uint256 private constant MESSAGE_SOURCE_DOMAIN_INDEX = 4;
    uint8 private constant SENDER_INDEX = 44;
    uint8 private constant RECIPIENT_INDEX = 76;
    uint8 private constant FINALITY_THRESHOLD_EXECUTED_INDEX = 144;
    uint256 private constant MESSAGE_BODY_INDEX = 148;

    uint256 private constant BODY_HOOK_DATA_INDEX = 228;

    address private attester;

    constructor(address _attester) {
        attester = _attester;
    }

    function receiveMessage(bytes calldata message, bytes calldata attestation)
        external
        override
        returns (bool success)
    {
        if (faultyMode) {
            return false;
        }

        if (ECDSA.recover(keccak256(message), attestation) != attester) {
            revert InvalidAttestation();
        }

        if (message.length < MESSAGE_BODY_INDEX + BODY_HOOK_DATA_INDEX) {
            revert InvalidMessage();
        }

        uint32 _sourceDomain = uint32(bytes4(_readBytes32(message, MESSAGE_SOURCE_DOMAIN_INDEX)));
        bytes32 _sender = _readBytes32(message, SENDER_INDEX);
        address _recipient = address(uint160(uint256(_readBytes32(message, RECIPIENT_INDEX))));
        uint32 _finalityThresholdExecuted = uint32(bytes4(_readBytes32(message, FINALITY_THRESHOLD_EXECUTED_INDEX)));
        bytes memory _messageBody = message[MESSAGE_BODY_INDEX:];

        MockCctpV2TokenMessenger(_recipient)
            .handleReceiveFinalizedMessage(_sourceDomain, _sender, _finalityThresholdExecuted, _messageBody);

        emit ReceiveMessage(message, attestation);

        return true;
    }

    function setFaultyMode(bool _faultyMode) public {
        faultyMode = _faultyMode;
    }

    function _readBytes32(bytes memory data, uint256 index) private pure returns (bytes32 result) {
        if (data.length < index + 32) {
            revert InvalidMessage();
        }
        assembly {
            result := mload(add(add(data, 0x20), index))
        }
    }
}
