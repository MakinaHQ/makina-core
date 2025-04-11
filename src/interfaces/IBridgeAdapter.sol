// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IBridgeAdapter {
    error BridgeTransferAlreadyCancelled();
    error BridgeTransferAlreadyClaimed();
    error BridgeTransferAlreadySent();
    error InsufficientBalance();
    error InsufficientOutputAmount();
    error InvalidRecipientChainId();
    error InvalidOutputToken();
    error InvalidSenderChainId();
    error InvalidTransferStatus();
    error MaxValueLossExceeded();
    error MessageAlreadyAuthorized();
    error NotController();
    error UnauthorizedSource();
    error UnexpectedMessage();

    event AuthorizeInBridgeTransfer(bytes32 indexed messageHash);
    event CancelOutBridgeTransfer(uint256 indexed transferId);
    event ClaimInBridgeTransfer(uint256 indexed transferId);
    event SendOutBridgeTransfer(uint256 indexed transferId);
    event ReceiveInBridgeTransfer(uint256 indexed transferId);
    event ScheduleOutBridgeTransfer(uint256 indexed transferId, bytes32 indexed messageHash);

    enum Bridge {
        ACROSS_V3,
        CIRCLE_CCTP
    }

    enum OutTransferStatus {
        NULL,
        SCHEDULED,
        SENT
    }

    enum InTransferStatus {
        NULL,
        RECEIVED
    }

    struct OutBridgeTransfer {
        address recipient;
        uint256 destinationChainId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 minOutputAmount;
        bytes encodedMessage;
        OutTransferStatus status;
    }

    struct InBridgeTransfer {
        address sender;
        uint256 originChainId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 outputAmount;
        InTransferStatus status;
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

    /// @notice Returns the address of the bridge controller contract.
    function controller() external view returns (address);

    /// @notice Returns the ID of the adapted external bridge.
    function bridgeId() external view returns (uint256);

    /// @notice Returns the address of the external bridge approval target contract.
    function approvalTarget() external view returns (address);

    /// @notice Returns the address of the external bridge execution target contract.
    function executionTarget() external view returns (address);

    /// @notice Returns the address of the external bridge contract responsible for sending output funds.
    function receiveSource() external view returns (address);

    /// @notice Returns the ID of the next outgoing transfer.
    function nextOutTransferId() external view returns (uint256);

    /// @notice Returns the ID of the next incoming transfer.
    function nextInTransferId() external view returns (uint256);

    /// @notice Schedules an outgoing bridge transfer and returns the message hash.
    /// @param destinationChainId The ID of the destination chain.
    /// @param recipient The address of the recipient on the destination chain.
    /// @param inputToken The address of the input token.
    /// @param inputAmount The amount of the input token to transfer.
    /// @param outputToken The address of the output token on the destination chain.
    /// @param minOutputAmount The minimum amount of the output token to receive.
    /// @return messageHash The hash of the bridge message.
    function scheduleOutBridgeTransfer(
        uint256 destinationChainId,
        address recipient,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) external returns (bytes32);

    /// @notice Executes a scheduled outgoing bridge transfer.
    /// @param transferId The ID of the transfer to execute.
    /// @param data The optional data needed to execute the transfer.
    function sendOutBridgeTransfer(uint256 transferId, bytes calldata data) external;

    /// @notice Returns the default amount that must be transferred to the adapter to cancel an outgoing bridge transfer.
    /// @dev If the transfer has not yet been sent or if the full amount was refunded by the external bridge, returns 0.
    /// @dev If the bridge retains a fee upon cancellation, the returned value reflects that fee.
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
}
