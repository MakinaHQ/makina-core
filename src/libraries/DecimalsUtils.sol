// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {LowLevelCall} from "@openzeppelin/contracts/utils/LowLevelCall.sol";
import {Memory} from "@openzeppelin/contracts/utils/Memory.sol";

import {Errors} from "./Errors.sol";

library DecimalsUtils {
    /// @dev Supported decimals range for assets
    uint8 private constant MIN_DECIMALS = 6;
    uint8 private constant MAX_DECIMALS = 18;

    /// @dev Decimals and unit for machine share token.
    uint8 internal constant SHARE_TOKEN_DECIMALS = 18;
    uint256 internal constant SHARE_TOKEN_UNIT = 10 ** SHARE_TOKEN_DECIMALS;

    /// @dev Checks that asset exposes decimals() and that it is within the supported range.
    function _checkDecimals(address asset) internal view {
        Memory.Pointer ptr = Memory.getFreeMemoryPointer();
        (bool success, bytes32 returnedDecimals,) =
            LowLevelCall.staticcallReturn64Bytes(address(asset), abi.encodeCall(IERC20Metadata.decimals, ()));
        Memory.unsafeSetFreeMemoryPointer(ptr);

        if (
            !success || LowLevelCall.returnDataSize() < 32 || uint256(returnedDecimals) < MIN_DECIMALS
                || uint256(returnedDecimals) > MAX_DECIMALS
        ) {
            revert Errors.InvalidDecimals();
        }
    }
}
