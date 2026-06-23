// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICreReceiver} from "../interfaces/ICreReceiver.sol";
import {ISpokeSnapshotConsumer} from "../interfaces/ISpokeSnapshotConsumer.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract SpokeSnapshotConsumer is AccessManagedUpgradeable, ERC165, ISpokeSnapshotConsumer {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @inheritdoc ISpokeSnapshotConsumer
    address public immutable override creForwarder;

    uint256 private constant CRE_METADATA_LENGTH = 64;

    /// @custom:storage-location erc7201:makina.storage.SpokeSnapshotConsumer
    struct SpokeSnapshotConsumerStorage {
        EnumerableSet.Bytes32Set _creWorkflowIds;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.SpokeSnapshotConsumer")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SpokeSnapshotConsumerStorageLocation =
        0xb63b6c1855ef12c3ce1467dc59d74e167a3a4f63f2ecef0203e34e2727af1300;

    function _getSpokeSnapshotConsumerStorage() private pure returns (SpokeSnapshotConsumerStorage storage $) {
        assembly {
            $.slot := SpokeSnapshotConsumerStorageLocation
        }
    }

    constructor(address _creForwarder) {
        creForwarder = _creForwarder;
    }

    function __SpokeSnapshotConsumer_init(SpokeSnapshotConsumerInitParams calldata sscParams)
        internal
        onlyInitializing
    {
        uint256 len = sscParams.initialCreWorkflowIds.length;
        for (uint256 i; i < len; ++i) {
            _addCreWorkflowId(sscParams.initialCreWorkflowIds[i]);
        }
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function isCreWorkflowIdAuthorized(bytes32 creWorkflowId) external view override returns (bool) {
        return _getSpokeSnapshotConsumerStorage()._creWorkflowIds.contains(creWorkflowId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ICreReceiver).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function addCreWorkflowId(bytes32 newCreWorkflowId) external override restricted {
        _addCreWorkflowId(newCreWorkflowId);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function removeCreWorkflowId(bytes32 creWorkflowId) external override restricted {
        _removeCreWorkflowId(creWorkflowId);
    }

    /// @dev Internal logic for adding a CRE workflow ID.
    function _addCreWorkflowId(bytes32 newCreWorkflowId) internal {
        if (!_getSpokeSnapshotConsumerStorage()._creWorkflowIds.add(newCreWorkflowId)) {
            revert Errors.CreWorkflowIdAlreadyAuthorized();
        }
        emit CreWorkflowIdAdded(newCreWorkflowId);
    }

    /// @dev Internal logic for removing a CRE workflow ID.
    function _removeCreWorkflowId(bytes32 creWorkflowId) internal {
        if (!_getSpokeSnapshotConsumerStorage()._creWorkflowIds.remove(creWorkflowId)) {
            revert Errors.CreWorkflowIdNotAuthorized();
        }
        emit CreWorkflowIdRemoved(creWorkflowId);
    }

    /// @dev Extracts fields from a CRE report metadata and validates them against stored values if any are set.
    function _validateMetadata(bytes calldata metadata) internal view {
        if (metadata.length != CRE_METADATA_LENGTH) {
            revert Errors.InvalidCreMetadataLength();
        }

        bytes32 workflowId;

        // metadata (64 bytes): [0:32) id | [32:42) name | [42:62) author | [62:64) unused
        assembly {
            workflowId := calldataload(metadata.offset)
        }

        if (!_getSpokeSnapshotConsumerStorage()._creWorkflowIds.contains(workflowId)) {
            revert Errors.InvalidCreWorkflowId();
        }
    }
}
