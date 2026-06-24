// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ICreReceiver} from "./ICreReceiver.sol";

interface ISpokeSnapshotConsumer is ICreReceiver {
    event CreWorkflowIdAdded(bytes32 indexed newCreWorkflowId);
    event CreWorkflowIdRemoved(bytes32 indexed creWorkflowId);

    struct SpokeSnapshotConsumerInitParams {
        bytes32[] initialCreWorkflowIds;
    }

    /// @notice Address of the Chainlink CRE forwarder.
    function creForwarder() external view returns (address);

    /// @notice CRE workflow ID => Whether the ID is authorized.
    function isCreWorkflowIdAuthorized(bytes32 creWorkflowId) external view returns (bool);

    /// @notice Authorizes a CRE workflow ID.
    /// @param newCreWorkflowId The CRE workflow ID to authorize.
    function addCreWorkflowId(bytes32 newCreWorkflowId) external;

    /// @notice Deauthorizes a CRE workflow ID.
    /// @param creWorkflowId The CRE workflow ID to deauthorize.
    function removeCreWorkflowId(bytes32 creWorkflowId) external;
}
