// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library Roles {
    uint64 public constant INFRA_CONFIG_ROLE = 1;
    uint64 public constant STRATEGY_DEPLOYMENT_ROLE = 2;
    uint64 public constant STRATEGY_COMPONENTS_SETUP_ROLE = 3;
    uint64 public constant STRATEGY_MANAGEMENT_CONFIG_ROLE = 4;
    uint64 public constant INFRA_UPGRADE_ROLE = 5;
    uint64 public constant GUARDIAN_ROLE = 6;
}
