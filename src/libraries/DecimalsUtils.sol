// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LowLevelCall} from "@openzeppelin/contracts/utils/LowLevelCall.sol";
import {Memory} from "@openzeppelin/contracts/utils/Memory.sol";

library DecimalsUtils {
    uint8 internal constant DEFAULT_DECIMALS = 18;
    uint8 internal constant MIN_DECIMALS = 6;
    uint8 internal constant MAX_DECIMALS = DEFAULT_DECIMALS;
    uint8 internal constant SHARE_TOKEN_DECIMALS = DEFAULT_DECIMALS;
    uint256 internal constant SHARE_TOKEN_UNIT = 10 ** SHARE_TOKEN_DECIMALS;

    function _getDecimals(address asset) internal view returns (uint8) {
        Memory.Pointer ptr = Memory.getFreeMemoryPointer();
        (bool success, bytes32 returnedDecimals,) =
            LowLevelCall.staticcallReturn64Bytes(address(asset), abi.encodeCall(IERC20Metadata.decimals, ()));
        Memory.unsafeSetFreeMemoryPointer(ptr);

        return (success && LowLevelCall.returnDataSize() >= 32 && uint256(returnedDecimals) <= type(uint8).max)
            ? uint8(uint256(returnedDecimals))
            : DEFAULT_DECIMALS;
    }
}
