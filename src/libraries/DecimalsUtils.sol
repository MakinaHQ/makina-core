// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

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
        try IERC20Metadata(asset).decimals() returns (uint8 decimals_) {
            if (decimals_ < MIN_DECIMALS || decimals_ > MAX_DECIMALS) {
                revert Errors.InvalidDecimals();
            }
        } catch {
            revert Errors.InvalidDecimals();
        }
    }
}
