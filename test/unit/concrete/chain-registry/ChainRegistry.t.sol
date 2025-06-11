// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ChainRegistry} from "src/registries/ChainRegistry.sol";

import {Base_Test} from "test/base/Base.t.sol";

contract ChainRegistry_Unit_Concrete_Test is Base_Test {
    uint256 public evmChainId;
    uint16 public whChainId;

    ChainRegistry public chainRegistry;

    function setUp() public virtual override {
        Base_Test.setUp();
        HubCore memory deployment = deployHubCore(deployer, dao, address(0));
        chainRegistry = deployment.chainRegistry;
        _setupChainRegistryAMFunctionRoles(deployment.accessManager, address(chainRegistry));
        setupAccessManagerRoles(deployment.accessManager, dao, deployer);
    }
}
