// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

contract Constants {
    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    string public constant DEFAULT_MACHINE_SHARE_TOKEN_NAME = "Machine Share";
    string public constant DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL = "MS";
    uint256 public constant DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD = 30 minutes;
    uint256 public constant DEFAULT_MACHINE_SHARE_LIMIT = type(uint256).max;

    uint256 public constant DEFAULT_CALIBER_POS_STALE_THRESHOLD = 20 minutes;
    uint256 public constant DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK = 1 hours;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS = 100;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS = 1000;
    uint256 public constant DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS = 200;

    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant SUPPLY_POS_ID = 4;
    uint256 internal constant BORROW_POS_ID = 5;
    uint256 internal constant POOL_POS_ID = 6;

    uint16 public constant WORMHOLE_HUB_CHAIN_ID = 2;
}
