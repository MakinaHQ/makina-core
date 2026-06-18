// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICreReceiver} from "../../src/interfaces/ICreReceiver.sol";

/// @dev MockCreForwarder contract for testing use only
///      Permissionless reporting
contract MockCreForwarder {
    bytes2 private constant DEFAULT_REPORT_ID = 0x0000;

    function forwardReport(
        address receiver,
        bytes calldata report,
        bytes32 workflowCid,
        address workflowAuthor,
        bytes10 workflowName
    ) external {
        bytes memory metadata = abi.encodePacked(workflowCid, workflowName, workflowAuthor, DEFAULT_REPORT_ID);
        ICreReceiver(receiver).onReport(metadata, report);
    }
}
