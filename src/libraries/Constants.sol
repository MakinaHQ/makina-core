// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

library Constants {
    uint8 internal constant SHARE_TOKEN_DECIMALS = 18;
    uint8 internal constant MIN_ACCOUNTING_TOKEN_DECIMALS = 6;
    uint8 internal constant MAX_ACCOUNTING_TOKEN_DECIMALS = SHARE_TOKEN_DECIMALS;

    uint256 internal constant SHARE_TOKEN_UNIT = 10 ** SHARE_TOKEN_DECIMALS;
}
