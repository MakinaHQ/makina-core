// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICctpV2DestinationCaller {
    /// @notice Handles reception of a CCTP V2 message and signature.
    /// @param message The CCTP V2 message raw bytes.
    /// @param attestation The message signature.
    function receiveCctpV2Message(bytes calldata message, bytes calldata attestation) external;
}
