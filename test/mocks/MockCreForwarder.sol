// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICreReceiver} from "../../src/interfaces/ICreReceiver.sol";

/// @dev MockCreForwarder contract for testing use only
///      Permissionless reporting
contract MockCreForwarder {
    bytes2 private constant DEFAULT_REPORT_ID = 0x0000;

    function forwardReport(address receiver, bytes calldata report, bytes32 workflowId) external {
        bytes memory metadata = abi.encodePacked(workflowId, bytes10(0), address(0), DEFAULT_REPORT_ID);
        ICreReceiver(receiver).onReport(metadata, report);
    }
}
