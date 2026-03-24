// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "./Errors.sol";

library CctpV2Message {
    /// @dev Indexes in message
    uint256 private constant MESSAGE_SOURCE_DOMAIN_INDEX = 4;
    uint256 private constant MESSAGE_BODY_INDEX = 148;

    /// @dev Indexes in message body
    uint256 private constant BODY_BURN_TOKEN_INDEX = 4;
    uint256 private constant BODY_HOOK_DATA_INDEX = 228;

    /// @dev Checks that `message` has the minimum length required for parsing.
    ///      Must be called before parsing.
    function checkMessageLength(bytes calldata message) internal pure {
        unchecked {
            if (message.length < MESSAGE_BODY_INDEX + BODY_HOOK_DATA_INDEX) {
                revert Errors.InvalidCctpMessage();
            }
        }
    }

    /// @dev Returns the source domain.
    function getSourceDomain(bytes calldata message) internal pure returns (uint32) {
        bytes32 result;
        assembly {
            result := calldataload(add(message.offset, MESSAGE_SOURCE_DOMAIN_INDEX))
        }

        return uint32(bytes4(result));
    }

    /// @dev Returns the burn token from the message body.
    function getBurnToken(bytes calldata message) internal pure returns (bytes32) {
        bytes32 result;
        assembly {
            result := calldataload(add(message.offset, add(MESSAGE_BODY_INDEX, BODY_BURN_TOKEN_INDEX)))
        }

        return result;
    }

    /// @dev Returns the hook data from the message body.
    function getHookData(bytes calldata message) internal pure returns (bytes memory) {
        return message[MESSAGE_BODY_INDEX + BODY_HOOK_DATA_INDEX:];
    }

    /// @dev Converts an address to bytes32.
    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
