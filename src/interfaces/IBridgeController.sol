// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeController {
    event BridgeAdapterCreated(uint16 indexed bridgeId, address indexed adapter);
    event MaxBridgeLossBpsChanged(
        uint16 indexed bridgeId, uint256 indexed oldMaxBridgeLossBps, uint256 indexed newMaxBridgeLossBps
    );
    event BridgingStateReset(address indexed token);
    event OutTransferEnabledSet(uint256 indexed bridgeId, bool enabled);

    /// @notice Bridge ID => Is bridge adapter deployed.
    function isBridgeSupported(uint16 bridgeId) external view returns (bool);

    /// @notice Bridge ID => Is outgoing transfer enabled.
    function isOutTransferEnabled(uint16 bridgeId) external view returns (bool);

    /// @notice Bridge ID => Address of the associated bridge adapter.
    function getBridgeAdapter(uint16 bridgeId) external view returns (address);

    /// @notice Bridge ID => Max allowed value loss in basis points for transfers via this bridge.
    function getMaxBridgeLossBps(uint16 bridgeId) external view returns (uint256);

    /// @notice Deploys a new BridgeAdapter instance.
    /// @param bridgeId The ID of the bridge.
    /// @param initialMaxBridgeLossBps The initial maximum allowed value loss in basis points for transfers via this bridge.
    /// @param initData The optional initialization data for the bridge adapter.
    /// @return The address of the deployed BridgeAdapter.
    function createBridgeAdapter(uint16 bridgeId, uint256 initialMaxBridgeLossBps, bytes calldata initData)
        external
        returns (address);

    /// @notice Sets the maximum allowed value loss in basis points for transfers via this bridge.
    /// @param bridgeId The ID of the bridge.
    /// @param maxBridgeLossBps The maximum allowed value loss in basis points.
    function setMaxBridgeLossBps(uint16 bridgeId, uint256 maxBridgeLossBps) external;

    /// @notice Sets the outgoing transfer enabled status for a bridge.
    /// @param bridgeId The ID of the bridge.
    /// @param enabled True to enable outgoing transfer for the given bridge ID, false to disable.
    function setOutTransferEnabled(uint16 bridgeId, bool enabled) external;

    /// @notice Executes a scheduled outgoing bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to execute.
    /// @param data The optional data needed to execute the transfer.
    function sendOutBridgeTransfer(uint16 bridgeId, uint256 transferId, bytes calldata data) external;

    /// @notice Registers a message hash as authorized for an incoming bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param messageHash The hash of the message to authorize.
    function authorizeInBridgeTransfer(uint16 bridgeId, bytes32 messageHash) external;

    /// @notice Transfers a received bridge transfer out of the adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to claim.
    function claimInBridgeTransfer(uint16 bridgeId, uint256 transferId) external;

    /// @notice Cancels an outgoing bridge transfer.
    /// @param bridgeId The ID of the bridge.
    /// @param transferId The ID of the transfer to cancel.
    function cancelOutBridgeTransfer(uint16 bridgeId, uint256 transferId) external;

    /// @notice Resets internal bridge counters for a given token, and withdraw token balances held by all bridge adapters.
    /// @dev This function is intended to be used by the DAO to realign bridge accounting state and maintain protocol consistency,
    ///      typically in response to operator deviations, external bridge discrepancies, or unbounded counter growth.
    /// @param token The address of the token.
    function resetBridgingState(address token) external;
}
