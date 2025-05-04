// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

abstract contract Constants {
    uint256 public constant DEFAULT_PF_STALE_THRSHLD = 2 hours;

    string public constant DEFAULT_MACHINE_SHARE_TOKEN_NAME = "Machine Share";
    string public constant DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL = "MS";
    uint256 public constant DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD = 30 minutes;
    uint256 public constant DEFAULT_MACHINE_MAX_FEE_ACCRUAL_RATE = 1e17;
    uint256 public constant DEFAULT_MACHINE_FEE_MINT_COOLDOWN = 8 hours;
    uint256 public constant DEFAULT_MACHINE_SHARE_LIMIT = type(uint256).max;

    uint256 public constant DEFAULT_CALIBER_POS_STALE_THRESHOLD = 20 minutes;
    uint256 public constant DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK = 1 hours;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS = 100;
    uint256 public constant DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS = 1000;
    uint256 public constant DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS = 200;
    uint256 public constant DEFAULT_CALIBER_COOLDOWN_DURATION = 60 seconds;

    uint256 public constant DEFAULT_MAX_BRIDGE_LOSS_BPS = 300;

    uint256 internal constant VAULT_POS_ID = 3;
    uint256 internal constant SUPPLY_POS_ID = 4;
    uint256 internal constant BORROW_POS_ID = 5;
    uint256 internal constant POOL_POS_ID = 6;
    uint256 internal constant LOOP_POS_ID = 7;

    uint16 public constant WORMHOLE_HUB_CHAIN_ID = 2;

    uint256 public constant DEFAULT_FEE_MANAGER_FIXED_FEE_RATE = 1e9;
    uint256 public constant DEFAULT_FEE_MANAGER_PERF_FEE_RATE = 1e10;

    uint16 public constant ACROSS_V3_BRIDGE_ID = 1;
    uint16 public constant CIRCLE_CCTP_BRIDGE_ID = 2;
}
