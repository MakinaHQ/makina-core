// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeAdapter {
    event InBridgeTransferAuthorized(bytes32 indexed messageHash);
    event OutBridgeTransferCancelled(uint256 indexed transferId);
    event InBridgeTransferClaimed(uint256 indexed transferId);
    event InBridgeTransferReceived(uint256 indexed transferId);
    event OutBridgeTransferSent(uint256 indexed transferId);
    event OutBridgeTransferScheduled(uint256 indexed transferId, bytes32 indexed messageHash);
    event PendingFundsWithdrawn(address indexed token, uint256 amount);

    struct OutBridgeTransfer {
        address recipient;
        uint256 destinationChainId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 minOutputAmount;
        bytes encodedMessage;
    }

    struct InBridgeTransfer {
        address sender;
        uint256 originChainId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 outputAmount;
    }

    struct BridgeMessage {
        uint256 outTransferId;
        address sender;
        address recipient;
        uint256 originChainId;
        uint256 destinationChainId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 minOutputAmount;
    }

    /// @notice Initializer of the contract.
    /// @param controller The bridge controller contract.
    /// @param initData The optional initialization data.
    function initialize(address controller, bytes calldata initData) external;

    /// @notice Address of the bridge controller contract.
    function controller() external view returns (address);

    /// @notice ID of the adapted external bridge.
    function bridgeId() external view returns (uint16);

    /// @notice Address of the external bridge approval target contract.
    function approvalTarget() external view returns (address);

    /// @notice Address of the external bridge execution target contract.
    function executionTarget() external view returns (address);

    /// @notice Address of the external bridge contract responsible for sending output funds.
    function receiveSource() external view returns (address);

    /// @notice ID of the next outgoing transfer.
    function nextOutTransferId() external view returns (uint256);

    /// @notice ID of the next incoming transfer.
    function nextInTransferId() external view returns (uint256);

    /// @notice Schedules an outgoing bridge transfer and returns the message hash.
    /// @dev Emits an event containing the id of the transfer and the hash of the bridge transfer message.
    /// @param destinationChainId The ID of the destination chain.
    /// @param recipient The address of the recipient on the destination chain.
    /// @param inputToken The address of the input token.
    /// @param inputAmount The amount of the input token to transfer.
    /// @param outputToken The address of the output token on the destination chain.
    /// @param minOutputAmount The minimum amount of the output token to receive.
    function scheduleOutBridgeTransfer(
        uint256 destinationChainId,
        address recipient,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) external;

    /// @notice Executes a scheduled outgoing bridge transfer.
    /// @param transferId The ID of the transfer to execute.
    /// @param data The optional data needed to execute the transfer.
    function sendOutBridgeTransfer(uint256 transferId, bytes calldata data) external;

    /// @notice Returns the default amount that must be transferred to the adapter to cancel an outgoing bridge transfer.
    /// @dev If the transfer has not yet been sent, or if the full amount was refunded to this contract by the external bridge, returns 0.
    /// @dev If the bridge retains a fee upon cancellation and only a partial refund was received, the returned value reflects that fee.
    /// @dev In all other cases (e.g. including pending refunds or successful bridge transfers), returns the full amount of the transfer.
    /// @param transferId The ID of the transfer to check.
    /// @return The amount required to cancel the transfer.
    function outBridgeTransferCancelDefault(uint256 transferId) external view returns (uint256);

    /// @notice Cancels an outgoing bridge transfer.
    /// @param transferId The ID of the transfer to cancel.
    function cancelOutBridgeTransfer(uint256 transferId) external;

    /// @notice Registers a message hash as authorized for an incoming bridge transfer.
    /// @param messageHash The hash of the message to authorize.
    function authorizeInBridgeTransfer(bytes32 messageHash) external;

    /// @notice Transfers a received bridge transfer out of the adapter.
    /// @param transferId The ID of the transfer to claim.
    function claimInBridgeTransfer(uint256 transferId) external;

    /// @notice Resets internal state for a given token address, and transfers token balance to associated controller.
    /// @dev This function is intended to be used by the DAO to unlock funds stuck in the adapter, typically
    /// in response to operator deviations or external bridge discrepancies.
    /// @param token The address of the token.
    function withdrawPendingFunds(address token) external;
}
