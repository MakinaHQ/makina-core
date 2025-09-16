// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library DecimalsUtils {
    uint8 internal constant DEFAULT_DECIMALS = 18;
    uint8 internal constant MIN_DECIMALS = 6;
    uint8 internal constant MAX_DECIMALS = DEFAULT_DECIMALS;
    uint8 internal constant SHARE_TOKEN_DECIMALS = DEFAULT_DECIMALS;
    uint256 internal constant SHARE_TOKEN_UNIT = 10 ** SHARE_TOKEN_DECIMALS;

    function _getDecimals(address asset) internal view returns (uint8) {
        (bool success, bytes memory encodedDecimals) = asset.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return uint8(returnedDecimals);
            }
        }
        return DEFAULT_DECIMALS;
    }
}
