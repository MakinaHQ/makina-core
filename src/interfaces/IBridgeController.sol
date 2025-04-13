// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IBridgeAdapter} from "./IBridgeAdapter.sol";

interface IBridgeController {
    error BridgeAdapterAlreadyExists();
    error BridgeAdapterDoesNotExist();
    error OutTransferDisabled();

    event BridgeAdapterCreated(uint256 indexed bridgeId, address indexed adapter);
    event SetOutTransferEnabled(uint256 indexed bridgeId, bool enabled);

    /// @notice Bridge ID => Is bridge adapter deployed.
    function isBridgeSupported(IBridgeAdapter.Bridge bridgeId) external view returns (bool);

    /// @notice Bridge ID => Is outgoing transfer enabled.
    function isOutTransferEnabled(IBridgeAdapter.Bridge bridgeId) external view returns (bool);

    /// @notice Returns the address of the bridge adapter for a given bridge ID.
    /// @param bridgeId The ID of the bridge.
    function getBridgeAdapter(IBridgeAdapter.Bridge bridgeId) external view returns (address);

    /// @notice Deploys a new BridgeAdapter instance.
    /// @param bridgeId The ID of the bridge.
    /// @param initData The optional initialization data for the bridge adapter.
    /// @return The address of the deployed BridgeAdapter.
    function createBridgeAdapter(IBridgeAdapter.Bridge bridgeId, bytes calldata initData) external returns (address);

    /// @notice Sets the outgoing transfer enabled status for a bridge.
    /// @param bridgeId The ID of the bridge.
    /// @param enabled True to enable outgoing transfer for the given bridge ID, false to disable.
    function setOutTransferEnabled(IBridgeAdapter.Bridge bridgeId, bool enabled) external;

    /// @notice Executes a scheduled outgoing bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to execute.
    /// @param data The optional data needed to execute the transfer.
    function sendOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId, bytes calldata data) external;

    /// @notice Registers a message hash as authorized for an incoming bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param messageHash The hash of the message to authorize.
    function authorizeInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, bytes32 messageHash) external;

    /// @notice Transfers a received bridge transfer out of the adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to claim.
    function claimInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) external;

    /// @notice Cancels an outgoing bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to cancel.
    function cancelOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) external;
}
