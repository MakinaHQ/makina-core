// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ICreReceiver} from "./ICreReceiver.sol";

interface ISpokeSnapshotConsumer is ICreReceiver {
    event CreWorkflowAuthorChanged(address indexed oldCreWorkflowAuthor, address indexed newCreWorkflowAuthor);
    event CreWorkflowIdAdded(bytes32 indexed newCreWorkflowId);
    event CreWorkflowIdRemoved(bytes32 indexed creWorkflowId);
    event CreWorkflowNameAdded(bytes10 indexed newCreWorkflowName);
    event CreWorkflowNameRemoved(bytes10 indexed creWorkflowName);

    struct SpokeSnapshotConsumerInitParams {
        address initialCreWorkflowAuthor;
        bytes32[] initialCreWorkflowIds;
        bytes10[] initialCreWorkflowNames;
    }

    /// @notice Address of the Chainlink CRE forwarder.
    function creForwarder() external view returns (address);

    /// @notice CRE workflow ID => Whether the ID is authorized.
    function isCreWorkflowIdAuthorized(bytes32 creWorkflowId) external view returns (bool);

    /// @notice CRE workflow name => Whether the name is authorized.
    function isCreWorkflowNameAuthorized(bytes10 creWorkflowName) external view returns (bool);

    /// @notice Address of the expected CRE workflow author.
    function creWorkflowAuthor() external view returns (address);

    /// @notice Authorizes a CRE workflow ID.
    /// @param newCreWorkflowId The CRE workflow ID to authorize.
    function addCreWorkflowId(bytes32 newCreWorkflowId) external;

    /// @notice Deauthorizes a CRE workflow ID.
    /// @param creWorkflowId The CRE workflow ID to deauthorize.
    function removeCreWorkflowId(bytes32 creWorkflowId) external;

    /// @notice Authorizes a CRE workflow name.
    /// @param newCreWorkflowName The CRE workflow name to authorize.
    function addCreWorkflowName(bytes10 newCreWorkflowName) external;

    /// @notice Deauthorizes a CRE workflow name.
    /// @param creWorkflowName The CRE workflow name to deauthorize.
    function removeCreWorkflowName(bytes10 creWorkflowName) external;

    /// @notice Sets a new CRE workflow author.
    /// @param newCreWorkflowAuthor The address of the new CRE workflow author.
    function setCreWorkflowAuthor(address newCreWorkflowAuthor) external;
}
