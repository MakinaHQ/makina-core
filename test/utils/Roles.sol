// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library Roles {
    uint64 public constant INFRA_SETUP_ROLE = 1;
    uint64 public constant STRATEGY_DEPLOYMENT_ROLE = 2;
    uint64 public constant STRATEGY_COMPONENTS_SETUP_ROLE = 3;
    uint64 public constant STRATEGY_MANAGEMENT_SETUP_ROLE = 4;
}
