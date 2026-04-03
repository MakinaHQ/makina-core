// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICctpV2MessageTransmitter {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool);
}
