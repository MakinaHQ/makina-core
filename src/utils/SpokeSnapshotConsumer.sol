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
    uint256 private constant CRE_METADATA_WORKFLOW_NAME_INDEX = 32;
    uint256 private constant CRE_METADATA_WORKFLOW_AUTHOR_INDEX = 42;

    /// @custom:storage-location erc7201:makina.storage.SpokeSnapshotConsumer
    struct SpokeSnapshotConsumerStorage {
        EnumerableSet.Bytes32Set _creWorkflowIds;
        EnumerableSet.Bytes32Set _creWorkflowNames;
        address _creWorkflowAuthor;
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
        for (uint256 i; i < sscParams.initialCreWorkflowIds.length; ++i) {
            _addCreWorkflowId(sscParams.initialCreWorkflowIds[i]);
        }
        for (uint256 i; i < sscParams.initialCreWorkflowNames.length; ++i) {
            _addCreWorkflowName(sscParams.initialCreWorkflowNames[i]);
        }
        _setCreWorkflowAuthor(sscParams.initialCreWorkflowAuthor);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function isCreWorkflowIdAuthorized(bytes32 creWorkflowId) external view override returns (bool) {
        return _getSpokeSnapshotConsumerStorage()._creWorkflowIds.contains(creWorkflowId);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function isCreWorkflowNameAuthorized(bytes10 creWorkflowName) external view override returns (bool) {
        return _getSpokeSnapshotConsumerStorage()._creWorkflowNames.contains(bytes32(creWorkflowName));
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function creWorkflowAuthor() external view override returns (address) {
        return _getSpokeSnapshotConsumerStorage()._creWorkflowAuthor;
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

    /// @inheritdoc ISpokeSnapshotConsumer
    function addCreWorkflowName(bytes10 newCreWorkflowName) external override restricted {
        _addCreWorkflowName(newCreWorkflowName);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function removeCreWorkflowName(bytes10 creWorkflowName) external override restricted {
        _removeCreWorkflowName(creWorkflowName);
    }

    /// @inheritdoc ISpokeSnapshotConsumer
    function setCreWorkflowAuthor(address newCreWorkflowAuthor) external override restricted {
        _setCreWorkflowAuthor(newCreWorkflowAuthor);
    }

    /// @dev Internal logic for adding a CRE workflow ID.
    function _addCreWorkflowId(bytes32 newCreWorkflowId) internal {
        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();
        if (!$._creWorkflowIds.add(newCreWorkflowId)) {
            revert Errors.CreWorkflowIdAlreadyAuthorized();
        }
        emit CreWorkflowIdAdded(newCreWorkflowId);
    }

    /// @dev Internal logic for removing a CRE workflow ID.
    function _removeCreWorkflowId(bytes32 creWorkflowId) internal {
        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();
        if (!$._creWorkflowIds.remove(creWorkflowId)) {
            revert Errors.CreWorkflowIdNotAuthorized();
        }
        if ($._creWorkflowIds.length() == 0 && $._creWorkflowAuthor == address(0)) {
            revert Errors.CreWorkflowAuthorRequired();
        }
        emit CreWorkflowIdRemoved(creWorkflowId);
    }

    /// @dev Internal logic for adding a CRE workflow name.
    function _addCreWorkflowName(bytes10 newCreWorkflowName) internal {
        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();
        if (!$._creWorkflowNames.add(bytes32(newCreWorkflowName))) {
            revert Errors.CreWorkflowNameAlreadyAuthorized();
        }
        emit CreWorkflowNameAdded(newCreWorkflowName);
    }

    /// @dev Internal logic for removing a CRE workflow name.
    function _removeCreWorkflowName(bytes10 creWorkflowName) internal {
        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();
        if (!$._creWorkflowNames.remove(bytes32(creWorkflowName))) {
            revert Errors.CreWorkflowNameNotAuthorized();
        }
        emit CreWorkflowNameRemoved(creWorkflowName);
    }

    /// @dev Internal logic for setting the CRE workflow author.
    function _setCreWorkflowAuthor(address newCreWorkflowAuthor) internal {
        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();
        if (newCreWorkflowAuthor == address(0) && $._creWorkflowIds.length() == 0) {
            revert Errors.CreWorkflowAuthorRequired();
        }
        emit CreWorkflowAuthorChanged($._creWorkflowAuthor, newCreWorkflowAuthor);
        $._creWorkflowAuthor = newCreWorkflowAuthor;
    }

    /// @dev Extracts fields from a CRE report metadata and validates them against stored values if any are set.
    function _validateMetadata(bytes calldata metadata) internal view {
        if (metadata.length != CRE_METADATA_LENGTH) {
            revert Errors.InvalidCreMetadataLength();
        }

        bytes32 workflowId;
        bytes10 workflowName;
        address workflowAuthor;

        // metadata (64 bytes): [0:32) id | [32:42) name | [42:62) author | [62:64) unused
        assembly {
            let offset := metadata.offset
            workflowId := calldataload(offset)
            workflowName := calldataload(add(offset, CRE_METADATA_WORKFLOW_NAME_INDEX))
            // reads [42:74); shr drops the low 12 bytes incl. the [64:74) out-of-bounds tail, leaving address [42:62)
            workflowAuthor := shr(96, calldataload(add(offset, CRE_METADATA_WORKFLOW_AUTHOR_INDEX)))
        }

        SpokeSnapshotConsumerStorage storage $ = _getSpokeSnapshotConsumerStorage();

        EnumerableSet.Bytes32Set storage ids = $._creWorkflowIds;
        if (ids.length() != 0 && !ids.contains(workflowId)) {
            revert Errors.InvalidCreWorkflowId();
        }

        EnumerableSet.Bytes32Set storage names = $._creWorkflowNames;
        if (names.length() != 0 && !names.contains(bytes32(workflowName))) {
            revert Errors.InvalidCreWorkflowName();
        }

        address author = $._creWorkflowAuthor;
        if (author != address(0) && workflowAuthor != author) {
            revert Errors.InvalidCreWorkflowAuthor();
        }
    }
}
